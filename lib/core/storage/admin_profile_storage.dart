import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../services/user_firestore_sync.dart';

/// Persists the admin (app-user) profile details locally.
class AdminProfileStorage {
  static const _key = 'admin_profile_data_v1';

  static Future<void> save({
    String? userName,
    String? userHandle,
    String? userMiddleName,
    String? userEmail,
    String? userPhone,
    String? userGender,
    DateTime? userDateOfBirth,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    final data = <String, dynamic>{
      'userName': userName,
      'userHandle': userHandle,
      'userMiddleName': userMiddleName,
      'userEmail': userEmail,
      'userPhone': userPhone,
      'userGender': userGender,
      'userDateOfBirth': userDateOfBirth?.toIso8601String(),
    };
    await prefs.setString(_key, jsonEncode(data));

    UserFirestoreSync.instance.scheduleSettingsPatch({'adminProfile': data});
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
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_key);
    if (raw == null || raw.trim().isEmpty) return null;
    try {
      final decoded = jsonDecode(raw);
      if (decoded is! Map<String, dynamic>) return null;
      return decoded;
    } catch (_) {
      return null;
    }
  }

  static Future<void> clear() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_key);
  }
}
