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
  static const _prefsKey = 'notificationPrefs';
  static const _recordsKey = 'notificationRecords';
  static const _dismissedKey = 'notificationDismissedIds';

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
    final settings = await UserFirestoreSync.instance.loadSettings();
    final raw = settings?[_prefsKey];
    if (raw is Map<String, dynamic>) {
      return {...defaultPrefs, ...raw};
    }
    if (raw is Map) {
      return {...defaultPrefs, ...Map<String, dynamic>.from(raw)};
    }
    return Map.from(defaultPrefs);
  }

  static Future<void> savePrefs(Map<String, dynamic> data) async {
    await UserFirestoreSync.instance.patchSettingsNow({_prefsKey: data});
  }

  static Future<List<AppNotification>> loadRecords() async {
    final settings = await UserFirestoreSync.instance.loadSettings();
    final raw = settings?[_recordsKey];
    if (raw is List) {
      return raw
          .whereType<Map>()
          .map((e) => AppNotification.fromJson(Map<String, dynamic>.from(e)))
          .toList(growable: false);
    }
    return const <AppNotification>[];
  }

  static Future<void> saveRecords(List<AppNotification> records) async {
    final json = records.map((e) => e.toJson()).toList(growable: false);
    await UserFirestoreSync.instance.patchSettingsNow({_recordsKey: json});
  }

  static Future<void> clearRecords() async {
    await UserFirestoreSync.instance.patchSettingsNow({_recordsKey: []});
  }

  static Future<Set<String>> loadDismissedIds() async {
    final settings = await UserFirestoreSync.instance.loadSettings();
    final raw = settings?[_dismissedKey];
    if (raw is List) {
      return raw.whereType<String>().toSet();
    }
    return <String>{};
  }

  static Future<void> saveDismissedIds(Set<String> ids) async {
    await UserFirestoreSync.instance.patchSettingsNow({_dismissedKey: ids.toList(growable: false)});
  }
}
