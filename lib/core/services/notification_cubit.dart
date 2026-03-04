import 'package:flutter_bloc/flutter_bloc.dart';

import 'notification_storage.dart';
import 'notification_service.dart';
import '../../features/calendar/domain/entities/schedule_session.dart';
import '../../features/client/domain/entities/client.dart';
import '../../features/client/domain/entities/client_timeline_event.dart';

/* ────────── State ────────── */

class NotificationState {
  final List<AppNotification> records;
  final Map<String, dynamic> prefs;
  final bool loading;

  const NotificationState({
    this.records = const [],
    this.prefs = const {},
    this.loading = true,
  });

  bool get sessionReminders => prefs['sessionReminders'] == true;
  int get sessionLeadMinutes => (prefs['sessionLeadMinutes'] as int?) ?? 15;
  bool get paymentReminders => prefs['paymentReminders'] == true;
  int get paymentReminderHour => (prefs['paymentReminderHour'] as int?) ?? 8;
  int get paymentReminderMinute => (prefs['paymentReminderMinute'] as int?) ?? 0;
  int get paymentDaysBefore => (prefs['paymentDaysBefore'] as int?) ?? 0;
  bool get paymentOverdueDaily => prefs['paymentOverdueDaily'] == true;

  int get unreadCount => records.where((e) => !e.read).length;

  NotificationState copyWith({
    List<AppNotification>? records,
    Map<String, dynamic>? prefs,
    bool? loading,
  }) {
    return NotificationState(
      records: records ?? this.records,
      prefs: prefs ?? this.prefs,
      loading: loading ?? this.loading,
    );
  }
}

/* ────────── Cubit ────────── */

class NotificationCubit extends Cubit<NotificationState> {
  NotificationCubit() : super(const NotificationState());

  /// Tracks scheduled OS notification IDs so we can cancel them selectively.
  final Set<int> _scheduledSessionIds = {};
  final Set<int> _scheduledPaymentIds = {};

  /// Load persisted records and preferences.
  Future<void> load() async {
    final prefs = await NotificationStorage.loadPrefs();
    final records = await NotificationStorage.loadRecords();
    // Sort newest first.
    records.sort((a, b) => b.createdAt.compareTo(a.createdAt));
    emit(state.copyWith(prefs: prefs, records: records, loading: false));
  }

  /* ────── Preference toggles ────── */

  Future<void> toggleSessionReminders(bool value) async {
    final updated = {...state.prefs, 'sessionReminders': value};
    emit(state.copyWith(prefs: updated));
    await NotificationStorage.savePrefs(updated);
    if (!value) {
      // Cancel only session reminders we actually scheduled.
      final svc = NotificationService.instance;
      for (final id in _scheduledSessionIds) {
        await svc.cancel(id);
      }
      _scheduledSessionIds.clear();
    }
  }

  Future<void> setSessionLeadMinutes(int minutes) async {
    final updated = {...state.prefs, 'sessionLeadMinutes': minutes};
    emit(state.copyWith(prefs: updated));
    await NotificationStorage.savePrefs(updated);
  }

  Future<void> togglePaymentReminders(bool value) async {
    final updated = {...state.prefs, 'paymentReminders': value};
    emit(state.copyWith(prefs: updated));
    await NotificationStorage.savePrefs(updated);
    if (!value) {
      final svc = NotificationService.instance;
      for (final id in _scheduledPaymentIds) {
        await svc.cancel(id);
      }
      _scheduledPaymentIds.clear();
    }
  }

  Future<void> setPaymentReminderTime(int hour, int minute) async {
    final updated = {
      ...state.prefs,
      'paymentReminderHour': hour,
      'paymentReminderMinute': minute,
    };
    emit(state.copyWith(prefs: updated));
    await NotificationStorage.savePrefs(updated);
  }

  Future<void> setPaymentDaysBefore(int days) async {
    final updated = {...state.prefs, 'paymentDaysBefore': days};
    emit(state.copyWith(prefs: updated));
    await NotificationStorage.savePrefs(updated);
  }

  Future<void> togglePaymentOverdueDaily(bool value) async {
    final updated = {...state.prefs, 'paymentOverdueDaily': value};
    emit(state.copyWith(prefs: updated));
    await NotificationStorage.savePrefs(updated);
  }

  /* ────── In-app record management ────── */

  static const _maxRecords = 200;

  Future<void> addRecord(AppNotification record) async {
    // Skip if a record with the same id already exists.
    if (state.records.any((e) => e.id == record.id)) return;
    var updated = [record, ...state.records];
    // Prune oldest records beyond the cap.
    if (updated.length > _maxRecords) {
      updated = updated.sublist(0, _maxRecords);
    }
    emit(state.copyWith(records: updated));
    await NotificationStorage.saveRecords(updated);
  }

  Future<void> markRead(String id) async {
    final updated = state.records
        .map((e) => e.id == id ? e.copyWith(read: true) : e)
        .toList();
    emit(state.copyWith(records: updated));
    await NotificationStorage.saveRecords(updated);
  }

  Future<void> markAllRead() async {
    final updated =
        state.records.map((e) => e.copyWith(read: true)).toList();
    emit(state.copyWith(records: updated));
    await NotificationStorage.saveRecords(updated);
  }

  Future<void> deleteRecord(String id) async {
    final updated = state.records.where((e) => e.id != id).toList();
    emit(state.copyWith(records: updated));
    await NotificationStorage.saveRecords(updated);
  }

  Future<void> clearAll() async {
    emit(state.copyWith(records: []));
    await NotificationStorage.clearRecords();
  }

  /* ────── Schedule session reminders ────── */

  /// Call whenever sessions change.  Reschedules all future session reminders.
  Future<void> scheduleSessionReminders(List<ScheduleSession> sessions) async {
    if (!state.sessionReminders) return;

    final svc = NotificationService.instance;
    final now = DateTime.now();
    final leadMin = state.sessionLeadMinutes;

    for (final session in sessions) {
      if (session.status == 'Completed' || session.status == 'Cancelled') {
        continue;
      }

      final dt = _parseSessionDateTime(session.date, session.time);
      if (dt == null) continue;

      final notifyAt = dt.subtract(Duration(minutes: leadMin));
      if (notifyAt.isBefore(now)) continue;

      final id = (session.hashCode & 0x7FFFFFFF) % 100000 + 100000; // 100_000–199_999

      final clientName = session.courseName ?? 'Session';
      await svc.schedule(
        id: id,
        title: 'Upcoming session',
        body: '$clientName — session #${session.sessionNo} in $leadMin min',
        scheduledAt: notifyAt,
        payload: 'session:${session.clientId}',
      );
      _scheduledSessionIds.add(id);

      // Also add an in-app record.
      await addRecord(AppNotification(
        id: 'session_${session.hashCode}_$leadMin',
        title: 'Upcoming session',
        body: '$clientName — session #${session.sessionNo} at ${session.time}',
        type: AppNotificationType.sessionReminder,
        createdAt: notifyAt,
      ));
    }
  }

  /* ────── Schedule payment reminders ────── */

  /// Call whenever clients change.
  /// Cancels old payment notifications, then schedules one morning notification
  /// per day that has unpaid payments on that specific date.
  /// Also schedules daily overdue reminders if enabled.
  Future<void> schedulePaymentReminders(List<Client> clients) async {
    if (!state.paymentReminders) return;

    final svc = NotificationService.instance;

    // Cancel previously scheduled payment notifications.
    for (final id in _scheduledPaymentIds) {
      await svc.cancel(id);
    }
    _scheduledPaymentIds.clear();

    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final hour = state.paymentReminderHour;
    final minute = state.paymentReminderMinute;
    final daysBefore = state.paymentDaysBefore;
    final overdueDaily = state.paymentOverdueDaily;

    // Collect all unpaid payment events grouped by their due date.
    final Map<String, List<_PaymentInfo>> byDate = {};

    for (final client in clients) {
      for (final pay in client.payments) {
        final payDate = DateTime(
            pay.createdAt.year, pay.createdAt.month, pay.createdAt.day);
        final dateKey =
            '${payDate.year}-${payDate.month.toString().padLeft(2, '0')}-${payDate.day.toString().padLeft(2, '0')}';

        // Check if already paid.
        bool isPaid = false;
        for (final e in client.timeline.reversed) {
          if (e.type != ClientTimelineEventType.statusChanged) continue;
          final eKey =
              '${e.createdAt.year}-${e.createdAt.month.toString().padLeft(2, '0')}-${e.createdAt.day.toString().padLeft(2, '0')}';
          if (eKey != dateKey) continue;
          final s = e.status?.trim();
          if (s == 'Paid' || s == 'Paid fully') {
            isPaid = true;
            break;
          }
        }
        if (isPaid) continue;

        byDate.putIfAbsent(dateKey, () => []);
        byDate[dateKey]!.add(_PaymentInfo(
          clientName: client.displayName,
          amount: pay.amount,
          payDate: payDate,
          clientId: client.id,
          payId: pay.id,
        ));
      }
    }

    // Schedule one notification per date that has unpaid payments.
    for (final entry in byDate.entries) {
      final payments = entry.value;
      if (payments.isEmpty) continue;
      final payDate = payments.first.payDate;
      final isOverdue = payDate.isBefore(today);

      // Build body — list each client + amount for that specific day.
      final String bodyText;
      if (payments.length == 1) {
        final p = payments.first;
        final amt = p.amount != null ? '₹${p.amount}' : 'payment';
        bodyText = '${p.clientName} — $amt';
      } else {
        final details = payments.map((p) {
          final amt = p.amount != null ? '₹${p.amount}' : '?';
          return '${p.clientName} $amt';
        }).join(', ');
        bodyText = '${payments.length} payments: $details';
      }

      // --- Future / today payments ---
      if (!isOverdue) {
        // 1) Advance reminder: daysBefore before the payment date.
        if (daysBefore > 0) {
          final advDate = payDate.subtract(Duration(days: daysBefore));
          final advNotifyAt = DateTime(
              advDate.year, advDate.month, advDate.day, hour, minute);
          if (advNotifyAt.isAfter(now)) {
            await _schedulePaymentNotification(
              svc: svc,
              dateKey: entry.key,
              scheduledAt: advNotifyAt,
              title: 'Payment in $daysBefore day${daysBefore > 1 ? 's' : ''}',
              body: bodyText,
              clientId: payments.first.clientId,
            );
          }
        }

        // 2) Same-day morning reminder on the actual due date.
        final sameDayNotify = DateTime(
            payDate.year, payDate.month, payDate.day, hour, minute);
        if (sameDayNotify.isAfter(now)) {
          await _schedulePaymentNotification(
            svc: svc,
            dateKey: entry.key,
            scheduledAt: sameDayNotify,
            title: 'Payment due today',
            body: bodyText,
            clientId: payments.first.clientId,
          );
        }
      }

      // --- Overdue payments ---
      if (isOverdue && overdueDaily) {
        // Schedule for today's morning or tomorrow if already past.
        final overdueAt = DateTime(today.year, today.month, today.day, hour, minute);
        final notifyAt = overdueAt.isAfter(now)
            ? overdueAt
            : DateTime(today.year, today.month, today.day + 1, hour, minute);

        await _schedulePaymentNotification(
          svc: svc,
          dateKey: entry.key,
          scheduledAt: notifyAt,
          title: 'Overdue payment',
          body: '$bodyText (due ${_formatDate(payDate)})',
          clientId: payments.first.clientId,
        );
      }
    }
  }

  /// Helper to schedule a single payment OS notification + in-app record.
  Future<void> _schedulePaymentNotification({
    required NotificationService svc,
    required String dateKey,
    required DateTime scheduledAt,
    required String title,
    required String body,
    required String clientId,
  }) async {
    final id =
        ((dateKey.hashCode ^ scheduledAt.hashCode) & 0x7FFFFFFF) % 100000 +
            200000;

    // Avoid duplicate OS notifications.
    if (_scheduledPaymentIds.contains(id)) return;

    await svc.schedule(
      id: id,
      title: title,
      body: body,
      scheduledAt: scheduledAt,
      payload: 'payment:$clientId',
    );
    _scheduledPaymentIds.add(id);

    await addRecord(AppNotification(
      id: 'payment_${dateKey}_${scheduledAt.millisecondsSinceEpoch}',
      title: title,
      body: body,
      type: AppNotificationType.paymentReminder,
      createdAt: scheduledAt,
    ));
  }

  /* ────── Helpers ────── */

  static DateTime? _parseSessionDateTime(String dateStr, String timeStr) {
    try {
      final parts = dateStr.split('-');
      final year = int.parse(parts[0]);
      final month = int.parse(parts[1]);
      final day = int.parse(parts[2]);

      final timeLower = timeStr.toLowerCase().trim();
      final isPm = timeLower.contains('pm');
      final cleaned =
          timeLower.replaceAll('am', '').replaceAll('pm', '').trim();
      final tParts = cleaned.split(':');
      var hour = int.parse(tParts[0]);
      final minute = tParts.length > 1 ? int.parse(tParts[1]) : 0;
      if (isPm && hour != 12) hour += 12;
      if (!isPm && hour == 12) hour = 0;

      return DateTime(year, month, day, hour, minute);
    } catch (_) {
      return null;
    }
  }

  static String _formatDate(DateTime d) =>
      '${d.day.toString().padLeft(2, '0')}-${d.month.toString().padLeft(2, '0')}-${d.year}';
}

/* ────────── Helpers ────────── */

class _PaymentInfo {
  final String clientName;
  final double? amount;
  final DateTime payDate;
  final String clientId;
  final String payId;

  const _PaymentInfo({
    required this.clientName,
    this.amount,
    required this.payDate,
    required this.clientId,
    required this.payId,
  });
}
