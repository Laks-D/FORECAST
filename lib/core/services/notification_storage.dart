import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

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
  static const _prefsKey = 'notification_prefs_v1';
  static const _recordsKey = 'notification_records_v1';

  /* ─────── Preferences ─────── */

  /// Default preferences.
  static const defaultPrefs = {
    'sessionReminders': true,
    'sessionLeadMinutes': 15,
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
        return {...defaultPrefs, ...decoded};
      }
    } catch (_) {}
    return Map.from(defaultPrefs);
  }

  static Future<void> savePrefs(Map<String, dynamic> data) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_prefsKey, jsonEncode(data));
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
}
