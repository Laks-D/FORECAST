import '../services/user_firestore_sync.dart';

/// Persists the admin (app-user) profile details in Firestore.
class AdminProfileStorage {
  static Future<void> save({
    String? userName,
    String? userHandle,
    String? userMiddleName,
    String? userEmail,
    String? userPhone,
    String? userGender,
    DateTime? userDateOfBirth,
  }) async {
    final data = <String, dynamic>{
      'userName': userName,
      'userHandle': userHandle,
      'userMiddleName': userMiddleName,
      'userEmail': userEmail,
      'userPhone': userPhone,
      'userGender': userGender,
      'userDateOfBirth': userDateOfBirth?.toIso8601String(),
    };

    await UserFirestoreSync.instance.patchSettingsNow({'adminProfile': data});
    await UserFirestoreSync.instance.upsertUserProfile(
      fullName: userName,
      handle: userHandle,
      middleName: userMiddleName,
      email: userEmail,
      phone: userPhone,
      gender: userGender,
      dateOfBirth: userDateOfBirth,
    );
  }

  static Future<Map<String, dynamic>?> load() async {
    final settings = await UserFirestoreSync.instance.loadSettings();
    final raw = settings?['adminProfile'];
    if (raw is Map<String, dynamic>) return raw;
    if (raw is Map) return Map<String, dynamic>.from(raw);
    return null;
  }

  static Future<void> clear() async {
    await UserFirestoreSync.instance.patchSettingsNow({'adminProfile': null});
  }
}
