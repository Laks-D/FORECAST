import 'dart:convert';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'user_firestore_sync.dart';

/// Types of in-app notifications.
enum AppNotificationType { sessionReminder, paymentReminder, general }

/// A single in-app notification record.
class AppNotification {
  final String id;
  final String title;
  final String body;
  final AppNotificationType type;
  final DateTime createdAt;
  final bool read;

  const AppNotification({
    required this.id,
    required this.title,
    required this.body,
    required this.type,
    required this.createdAt,
    this.read = false,
  });

  AppNotification copyWith({bool? read}) => AppNotification(
        id: id,
        title: title,
        body: body,
        type: type,
        createdAt: createdAt,
        read: read ?? this.read,
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'title': title,
        'body': body,
        'type': type.name,
        'createdAt': createdAt.toIso8601String(),
        'read': read,
      };

  factory AppNotification.fromJson(Map<String, dynamic> json) {
    return AppNotification(
      id: json['id'] as String,
      title: json['title'] as String,
      body: json['body'] as String,
      type: AppNotificationType.values.firstWhere(
        (e) => e.name == json['type'],
        orElse: () => AppNotificationType.general,
      ),
      createdAt: DateTime.parse(json['createdAt'] as String),
      read: (json['read'] as bool?) ?? false,
    );
  }
}

/// Persists notification preferences and in-app notification records.
class NotificationStorage {
  static const _prefsKeyBase = 'notification_prefs_v1';
  static const _recordsKeyBase = 'notification_records_v1';
  static const _dismissedKeyBase = 'notification_dismissed_v1';

  static String _uidSuffix() {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    // If there's no signed-in user, keep this separate from any real user's data.
    return uid == null || uid.trim().isEmpty ? '_signed_out' : '_$uid';
  }

  static String get _prefsKey => '$_prefsKeyBase${_uidSuffix()}';
  static String get _recordsKey => '$_recordsKeyBase${_uidSuffix()}';
  static String get _dismissedKey => '$_dismissedKeyBase${_uidSuffix()}';

  /* ─────── Preferences ─────── */

  /// Default preferences.
  static const defaultPrefs = {
    'sessionReminders': true,
    // Per requirement: remind 5 minutes before class.
    'sessionLeadMinutes': 5,
    'paymentReminders': true,
    'paymentReminderHour': 8,
    'paymentReminderMinute': 0,
    'paymentDaysBefore': 0,
    'paymentOverdueDaily': true,
  };

  static Future<Map<String, dynamic>> loadPrefs() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_prefsKey);
    if (raw == null) return Map.from(defaultPrefs);
    try {
      final decoded = jsonDecode(raw);
      if (decoded is Map<String, dynamic>) {
        final merged = {...defaultPrefs, ...decoded};

        // One-time migration: old default was 15 minutes, new default is 5.
        // If the stored value is missing or still 15, move it to 5.
        final migrated = merged['__migrated_session_lead_5'] == true;
        final storedLead = merged['sessionLeadMinutes'];
        if (!migrated && (storedLead == null || storedLead == 15)) {
          merged['sessionLeadMinutes'] = 5;
          merged['__migrated_session_lead_5'] = true;
          await prefs.setString(_prefsKey, jsonEncode(merged));
          // Also mirror to Firestore settings (best-effort).
          UserFirestoreSync.instance.scheduleSettingsPatch({'notificationPrefs': merged});
        }

        return merged;
      }
    } catch (_) {}
    return Map.from(defaultPrefs);
  }

  static Future<void> savePrefs(Map<String, dynamic> data) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_prefsKey, jsonEncode(data));

    UserFirestoreSync.instance.scheduleSettingsPatch({'notificationPrefs': data});
  }

  /* ─────── In-app records ─────── */

  static Future<List<AppNotification>> loadRecords() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_recordsKey);
    if (raw == null) return [];
    try {
      final decoded = jsonDecode(raw) as List<dynamic>;
      return decoded
          .map((e) => AppNotification.fromJson(e as Map<String, dynamic>))
          .toList();
    } catch (_) {
      return [];
    }
  }

  static Future<void> saveRecords(List<AppNotification> records) async {
    final prefs = await SharedPreferences.getInstance();
    final json = records.map((e) => e.toJson()).toList();
    await prefs.setString(_recordsKey, jsonEncode(json));
  }

  static Future<void> clearRecords() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_recordsKey);
  }

  /* ─────── Dismissed ids ─────── */

  static Future<Set<String>> loadDismissedIds() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_dismissedKey);
    if (raw == null) return <String>{};
    try {
      final decoded = jsonDecode(raw);
      if (decoded is List) {
        return decoded.whereType<String>().toSet();
      }
    } catch (_) {}
    return <String>{};
  }

  static Future<void> saveDismissedIds(Set<String> ids) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_dismissedKey, jsonEncode(ids.toList()));
  }
}
