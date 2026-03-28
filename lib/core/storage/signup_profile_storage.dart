import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../services/user_firestore_sync.dart';

class SignupProfileData {
  const SignupProfileData({
    this.fullName = '',
    this.profession = '',
    this.userName = '',
    this.email = '',
    this.selectedPrograms = const <String>[],
    this.preferences = const <String>[],
  });

  final String fullName;
  final String profession;
  final String userName;
  final String email;
  final List<String> selectedPrograms;
  final List<String> preferences;

  Map<String, dynamic> toJson() => {
        'fullName': fullName,
        'profession': profession,
        'userName': userName,
        'email': email,
        'selectedPrograms': selectedPrograms,
        'preferences': preferences,
      };

  factory SignupProfileData.fromJson(Map<String, dynamic> json) {
    return SignupProfileData(
      fullName: (json['fullName'] as String?) ?? '',
      profession: (json['profession'] as String?) ?? '',
      userName: (json['userName'] as String?) ?? '',
      email: (json['email'] as String?) ?? '',
      selectedPrograms: (json['selectedPrograms'] as List?)
              ?.map((e) => e.toString())
              .toList(growable: false) ??
          const <String>[],
      preferences: (json['preferences'] as List?)
              ?.map((e) => e.toString())
              .toList(growable: false) ??
          const <String>[],
    );
  }
}

class SignupProfileStorage {
  static const _key = 'signup_profile_data_v1';

  static Future<void> saveProfile(SignupProfileData data) async {
    final prefs = await SharedPreferences.getInstance();
    final jsonMap = data.toJson();
    await prefs.setString(_key, jsonEncode(jsonMap));

    UserFirestoreSync.instance.scheduleSettingsPatch({'signupProfile': jsonMap});
  }

  static Future<SignupProfileData?> getProfile() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_key);
    if (raw == null || raw.trim().isEmpty) return null;

    try {
      final decoded = jsonDecode(raw);
      if (decoded is! Map<String, dynamic>) return null;
      return SignupProfileData.fromJson(decoded);
    } catch (_) {
      return null;
    }
  }

  static Future<void> clear() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_key);
  }
}
