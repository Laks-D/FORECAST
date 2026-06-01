import 'dart:async';
import 'dart:io' show Platform;

import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart'
    as fln;
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:timezone/data/latest.dart' as tz;
import 'package:timezone/timezone.dart' as tz;

import '../../features/calendar/domain/entities/schedule_session.dart';
import '../../features/client/domain/entities/client.dart';

/// Local notification service (Device-side alarms layer).
///
/// Architecture: mirrors NurturingInstitute's dual-layer approach.
///   Layer 1 (this file)  — Device-local scheduled alarms (exact, timezone-aware).
///   Layer 2              — Firestore → Cloud Functions → FCM push (NotificationScheduler).
///
/// Call [scheduleAll] from [NotificationOrchestrator] whenever sessions or
/// clients change. User preferences from [NotificationCubit] are forwarded
/// through [NotificationOrchestrator.updatePreferences].
class NotificationService {
  NotificationService._();
  static final NotificationService instance = NotificationService._();

  final FlutterLocalNotificationsPlugin _plugin =
      FlutterLocalNotificationsPlugin();

  bool _initialized = false;

  // ─── Concurrency lock (mirrors NI's _isSchedulingNotifications) ───
  bool _isScheduling = false;
  bool _rescheduleQueued = false;
  List<Client>? _queuedClients;
  List<ScheduleSession>? _queuedSessions;

  // ─── Scheduling Preferences state to prevent config drift on deferred scheduler ───
  bool _sessionRemindersEnabled = true;
  int _sessionLeadMinutes = 5;
  bool _paymentRemindersEnabled = true;
  int _paymentHour = 8;
  int _paymentMinute = 0;
  int _paymentDaysBefore = 0;
  bool _paymentOverdueDaily = true;

  // ─── Debounce timer (mirrors NI's 2-second debounce) ───
  Timer? _debounce;

  // ─── Android notification channel IDs ───
  static const String _sessionChannelId = 'session_channel_v5';
  static const String _dailyChannelId = 'daily_channel_v5';
  static const String _paymentChannelId = 'payment_channel_v5';

  // ─── Notification ID namespaces ───
  static const int _dailySummaryId = 2000;
  static const int _groupedPaymentId = 99999;

  // ────────────────────────────────────────────────────────────────
  // Initialization
  // ────────────────────────────────────────────────────────────────

  Future<void> init() async {
    if (_initialized) return;
    if (kIsWeb) {
      _initialized = true;
      return;
    }

    try {
      debugPrint('🔔 Initializing NotificationService…');

      tz.initializeTimeZones();
      await _configureTimezone();

      const androidSettings =
          AndroidInitializationSettings('@mipmap/ic_launcher');

      const iosSettings = DarwinInitializationSettings(
        requestAlertPermission: true,
        requestBadgePermission: true,
        requestSoundPermission: true,
        defaultPresentAlert: true,
        defaultPresentBadge: true,
        defaultPresentSound: true,
      );

      await _plugin.initialize(
        settings: InitializationSettings(
          android: androidSettings,
          iOS: iosSettings,
        ),
        onDidReceiveNotificationResponse: (NotificationResponse r) {
          debugPrint('📱 Notification tapped: ${r.payload}');
        },
      );

      if (!kIsWeb && Platform.isAndroid) {
        await _createAndroidChannels();
        await _requestAndroidPermissions();
      }

      _initialized = true;
      debugPrint('✅ NotificationService initialized.');
    } catch (e) {
      debugPrint('❌ NotificationService init error: $e');
    }
  }

  // ────────────────────────────────────────────────────────────────
  // Public API
  // ────────────────────────────────────────────────────────────────

  /// Schedule all local notifications from scratch.
  /// Debounced by 2 seconds to absorb rapid state changes.
  void scheduleAll({
    required List<Client> clients,
    required List<ScheduleSession> sessions,
    bool sessionRemindersEnabled = true,
    int sessionLeadMinutes = 5,
    bool paymentRemindersEnabled = true,
    int paymentHour = 8,
    int paymentMinute = 0,
    int paymentDaysBefore = 0,
    bool paymentOverdueDaily = true,
  }) {
    _sessionRemindersEnabled = sessionRemindersEnabled;
    _sessionLeadMinutes = sessionLeadMinutes;
    _paymentRemindersEnabled = paymentRemindersEnabled;
    _paymentHour = paymentHour;
    _paymentMinute = paymentMinute;
    _paymentDaysBefore = paymentDaysBefore;
    _paymentOverdueDaily = paymentOverdueDaily;

    _debounce?.cancel();
    _debounce = Timer(const Duration(seconds: 2), () {
      _scheduleAllInternal(
        clients: clients,
        sessions: sessions,
      );
    });
  }

  /// Show an immediate local notification (used when FCM arrives in foreground).
  Future<void> show({
    required int id,
    required String title,
    required String body,
    String? payload,
  }) async {
    if (kIsWeb || !_initialized) return;
    await _plugin.show(
      id: id,
      title: title,
      body: body,
      notificationDetails: const NotificationDetails(
        android: AndroidNotificationDetails(
          _sessionChannelId,
          'Session Reminders',
          importance: Importance.high,
          priority: Priority.high,
        ),
        iOS: DarwinNotificationDetails(),
      ),
      payload: payload,
    );
  }

  Future<void> cancelAll() async {
    if (kIsWeb || !_initialized) return;
    await _plugin.cancelAll();
  }

  Future<void> cancel(int id) async {
    if (kIsWeb || !_initialized) return;
    await _plugin.cancel(id: id);
  }

  Future<bool> areNotificationsEnabled() async {
    if (kIsWeb || !_initialized) return false;
    if (Platform.isAndroid) {
      return await _plugin
              .resolvePlatformSpecificImplementation<
                  AndroidFlutterLocalNotificationsPlugin>()
              ?.areNotificationsEnabled() ??
          false;
    }
    if (Platform.isIOS) {
      return await _plugin
              .resolvePlatformSpecificImplementation<
                  IOSFlutterLocalNotificationsPlugin>()
              ?.requestPermissions(alert: true, sound: true) ??
          false;
    }
    return true;
  }

  // ────────────────────────────────────────────────────────────────
  // Internal scheduling (mirrors NI's _scheduleNotificationsBackground)
  // ────────────────────────────────────────────────────────────────

  Future<void> _scheduleAllInternal({
    required List<Client> clients,
    required List<ScheduleSession> sessions,
  }) async {
    if (_isScheduling) {
      _rescheduleQueued = true;
      _queuedClients = clients;
      _queuedSessions = sessions;
      return;
    }
    _isScheduling = true;

    try {
      if (kIsWeb || !_initialized) return;

      // Timezone guard.
      final dartNow = DateTime.now();
      final tzNow = tz.TZDateTime.now(tz.local);
      final tzOffset = tzNow.timeZoneOffset.inMinutes;
      final sysOffset = dartNow.timeZoneOffset.inMinutes;
      if (tzOffset == 0 && sysOffset != 0) {
        debugPrint('⚠️ TZ mismatch — reinitialising timezone…');
        await _configureTimezone();
        final retryNow = tz.TZDateTime.now(tz.local);
        if (retryNow.timeZoneOffset.inMinutes == 0 && sysOffset != 0) {
          debugPrint('❌ TZ still mismatched after retry — skipping pass.');
          return;
        }
      }

      // Wipe clean.
      await _plugin.cancelAll();
      debugPrint('🔔 Scheduling notifications (${sessions.length} sessions)…');

      // iOS Budget: 64 total.
      const int totalBudget = 64;
      const int reserveDaily = 1;
      int remaining = totalBudget - reserveDaily;

      final now = tz.TZDateTime.now(tz.local);
      final windowEnd = now.add(const Duration(days: 7));

      // ── Step 1: Payment daily digest ──
      if (_paymentRemindersEnabled) {
        remaining -= await _schedulePaymentDigest(
          clients: clients,
          now: now,
          paymentHour: _paymentHour,
          paymentMinute: _paymentMinute,
          paymentOverdueDaily: _paymentOverdueDaily,
          budget: remaining,
        );
      }

      // ── Step 2: Daily summary (reserved slot) ──
      await _scheduleDailySummary(now: now, sessions: sessions);

      // ── Step 3: Session reminders ──
      if (_sessionRemindersEnabled) {
        final upcoming = sessions.where((s) {
          final dt = _parseDateTime(s.date, s.time);
          return dt != null && dt.isAfter(now) && dt.isBefore(windowEnd);
        }).toList()
          ..sort((a, b) {
            final da = _parseDateTime(a.date, a.time) ?? now;
            final db = _parseDateTime(b.date, b.time) ?? now;
            return da.compareTo(db);
          });

        debugPrint(
            '📅 ${upcoming.length} sessions in next 7 days (budget: $remaining).');

        for (final session in upcoming) {
          if (remaining <= 0) break;
          final dt = _parseDateTime(session.date, session.time);
          if (dt == null || dt.isBefore(now)) continue;

          final clientName = _resolveClientName(clients, session.clientId);
          final startDisplay = session.time.split(' - ').first.trim();
          final diff = dt.difference(now);

          // 2-hour reminder (if session is more than 2 hours away).
          if (diff.inMinutes >= 120 && remaining >= 1) {
            await _scheduleExact(
              id: _safeId(session.id, 2),
              title: 'Session in 2 hours',
              body: 'Class with $clientName at $startDisplay.',
              scheduledTime: tz.TZDateTime.from(
                  dt.subtract(const Duration(hours: 2)), tz.local),
              channelId: _sessionChannelId,
            );
            remaining--;
          }

          // Lead-time reminder (user-configurable minutes before session).
          final leadDuration = Duration(minutes: _sessionLeadMinutes);
          final tMinus = dt.subtract(leadDuration);
          if (tMinus.isAfter(now) && remaining >= 1) {
            final label = _sessionLeadMinutes >= 60
                ? '${_sessionLeadMinutes ~/ 60}h'
                : '${_sessionLeadMinutes}m';
            await _scheduleExact(
              id: _safeId(session.id, 1),
              title: 'Session in $label',
              body: 'Class with $clientName at $startDisplay.',
              scheduledTime: tz.TZDateTime.from(tMinus, tz.local),
              channelId: _sessionChannelId,
            );
            remaining--;
          }
        }
      }

      debugPrint('✅ Notification scheduling complete.');
    } catch (e) {
      debugPrint('❌ _scheduleAllInternal error: $e');
    } finally {
      final queuedFlag = _rescheduleQueued;
      final qClients = _queuedClients;
      final qSessions = _queuedSessions;
      _rescheduleQueued = false;
      _queuedClients = null;
      _queuedSessions = null;
      _isScheduling = false;

      if (queuedFlag && qClients != null && qSessions != null) {
        debugPrint('🔁 Running deferred notification scheduling…');
        _scheduleAllInternal(
          clients: qClients,
          sessions: qSessions,
        );
      }
    }
  }

  // ────────────────────────────────────────────────────────────────
  // Payment digest
  // Note: In this app, payment "due dates" are managed via NotificationScheduler
  // writing Firestore docs for Cloud Functions to fire (backend layer).
  // Here we schedule a local daily digest for tutors reviewing active clients.
  // ────────────────────────────────────────────────────────────────

  Future<int> _schedulePaymentDigest({
    required List<Client> clients,
    required tz.TZDateTime now,
    required int paymentHour,
    required int paymentMinute,
    required bool paymentOverdueDaily,
    required int budget,
  }) async {
    if (!paymentOverdueDaily || clients.isEmpty || budget <= 0) return 0;

    final activeCount =
        clients.where((c) => c.deletedAt == null && c.payments.isNotEmpty).length;
    if (activeCount == 0) return 0;

    var target = tz.TZDateTime(
        tz.local, now.year, now.month, now.day, paymentHour, paymentMinute);
    if (target.isBefore(now)) {
      target = target.add(const Duration(days: 1));
    }

    await _scheduleExact(
      id: _groupedPaymentId,
      title: 'Daily Payments Check',
      body:
          'Review payments for your $activeCount active client${activeCount == 1 ? '' : 's'}.',
      scheduledTime: target,
      channelId: _paymentChannelId,
    );
    return 1;
  }

  // ────────────────────────────────────────────────────────────────
  // Daily summary (7 AM)
  // ────────────────────────────────────────────────────────────────

  Future<void> _scheduleDailySummary({
    required tz.TZDateTime now,
    required List<ScheduleSession> sessions,
  }) async {
    try {
      var target7am =
          tz.TZDateTime(tz.local, now.year, now.month, now.day, 7);
      if (now.isAfter(target7am)) {
        target7am = target7am.add(const Duration(days: 1));
      }

      final targetDate =
          DateTime(target7am.year, target7am.month, target7am.day);
      final count = sessions.where((s) {
        try {
          final d = DateTime.parse(s.date);
          return d.year == targetDate.year &&
              d.month == targetDate.month &&
              d.day == targetDate.day;
        } catch (_) {
          return false;
        }
      }).length;

      await _scheduleExact(
        id: _dailySummaryId,
        title: 'Daily Summary',
        body: count == 0
            ? 'No sessions scheduled for today.'
            : 'You have $count session${count == 1 ? '' : 's'} today.',
        scheduledTime: target7am,
        channelId: _dailyChannelId,
      );
    } catch (e) {
      debugPrint('❌ Daily summary scheduling error: $e');
    }
  }

  // ────────────────────────────────────────────────────────────────
  // Core scheduler (exact alarm)
  // ────────────────────────────────────────────────────────────────

  Future<void> _scheduleExact({
    required int id,
    required String title,
    required String body,
    required tz.TZDateTime scheduledTime,
    required String channelId,
  }) async {
    debugPrint('   ✅ SCHEDULE: id=$id | $scheduledTime | "$title"');
    await _plugin.zonedSchedule(
      id: id,
      title: title,
      body: body,
      scheduledDate: scheduledTime,
      notificationDetails: NotificationDetails(
        android: AndroidNotificationDetails(
          channelId,
          'Notification',
          importance: Importance.max,
          priority: Priority.high,
        ),
        iOS: const DarwinNotificationDetails(),
      ),
      androidScheduleMode: fln.AndroidScheduleMode.exactAllowWhileIdle,
    );
  }

  // ────────────────────────────────────────────────────────────────
  // Android channels & permissions
  // ────────────────────────────────────────────────────────────────

  Future<void> _createAndroidChannels() async {
    final impl = _plugin.resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin>();
    if (impl == null) return;

    await impl.createNotificationChannel(const AndroidNotificationChannel(
      _sessionChannelId,
      'Session Reminders',
      description: 'Reminders for upcoming sessions (2h and configurable lead time)',
      importance: Importance.max,
      playSound: true,
      enableVibration: true,
    ));

    await impl.createNotificationChannel(const AndroidNotificationChannel(
      _dailyChannelId,
      'Daily Summary',
      description: 'Daily schedule summary at 7 AM',
      importance: Importance.defaultImportance,
      playSound: true,
    ));

    await impl.createNotificationChannel(const AndroidNotificationChannel(
      _paymentChannelId,
      'Payment Reminders',
      description: 'Daily payment check and reminders',
      importance: Importance.high,
      playSound: true,
    ));
  }

  Future<void> _requestAndroidPermissions() async {
    final impl = _plugin.resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin>();
    if (impl == null) return;
    await impl.requestNotificationsPermission();
    try {
      await impl.requestExactAlarmsPermission();
    } catch (_) {
      // Older Android APIs don't need this; ignore.
    }
  }

  // ────────────────────────────────────────────────────────────────
  // Timezone configuration (mirrors NI exactly)
  // ────────────────────────────────────────────────────────────────

  Future<void> _configureTimezone() async {
    try {
      tz.initializeTimeZones();
      final dynamic timeZoneInfo = await FlutterTimezone.getLocalTimezone();
      final String timeZoneName = timeZoneInfo.toString();
      debugPrint('🌐 Device timezone: $timeZoneName');
      try {
        tz.setLocalLocation(tz.getLocation(timeZoneName));
      } catch (e) {
        debugPrint('⚠️ Error setting location "$timeZoneName": $e');
        if (DateTime.now().timeZoneOffset.inMinutes == 330) {
          debugPrint('🇮🇳 Detected IST offset, forcing Asia/Kolkata');
          tz.setLocalLocation(tz.getLocation('Asia/Kolkata'));
        } else {
          tz.setLocalLocation(tz.getLocation('UTC'));
        }
      }
    } catch (e) {
      debugPrint('❌ Timezone config failed: $e — using UTC.');
      tz.setLocalLocation(tz.getLocation('UTC'));
    }
  }

  // ────────────────────────────────────────────────────────────────
  // Utilities
  // ────────────────────────────────────────────────────────────────

  /// Parses "yyyy-MM-dd" date + "HH:mm AM/PM - HH:mm AM/PM" time string.
  tz.TZDateTime? _parseDateTime(String date, String time) {
    try {
      final dateParts = date.split('-');
      if (dateParts.length < 3) return null;
      final y = int.parse(dateParts[0]);
      final mo = int.parse(dateParts[1]);
      final d = int.parse(dateParts[2]);

      final startStr = time.split(' - ').first.trim();
      int hour = 0, minute = 0;

      if (startStr.contains(':')) {
        final isPm = startStr.toUpperCase().contains('PM');
        final isAm = startStr.toUpperCase().contains('AM');
        final hasMeridiem = isPm || isAm;
        final clean = startStr.replaceAll(RegExp(r'[^0-9:]'), '');
        final hm = clean.split(':');
        hour = int.parse(hm[0]);
        minute = hm.length > 1 ? int.parse(hm[1]) : 0;
        if (hasMeridiem) {
          if (isPm && hour < 12) hour += 12;
          if (isAm && hour == 12) hour = 0;
        }
      }

      return tz.TZDateTime.from(DateTime(y, mo, d, hour, minute), tz.local);
    } catch (_) {
      return null;
    }
  }

  String _resolveClientName(List<Client> clients, String clientId) {
    try {
      return clients.firstWhere((c) => c.id == clientId).name;
    } catch (_) {
      return 'your client';
    }
  }

  /// Generates a stable integer notification ID from a base ID + suffix namespace.
  int _safeId(Object baseId, int suffix) {
    return (baseId.hashCode & 0x7FFFFFFF) % 100000 + (suffix * 100000);
  }
}
