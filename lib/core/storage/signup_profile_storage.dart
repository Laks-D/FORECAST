import '../services/user_firestore_sync.dart';

class SignupProfileData {
  const SignupProfileData({
    this.fullName = '',
    this.profession = '',
    this.userName = '',
    this.email = '',
    this.nationality = 'India',
    this.currency = '₹',
    this.selectedPrograms = const <String>[],
    this.preferences = const <String>[],
  });

  final String fullName;
  final String profession;
  final String userName;
  final String email;
  final String nationality;
  final String currency;
  final List<String> selectedPrograms;
  final List<String> preferences;

  Map<String, dynamic> toJson() => {
        'fullName': fullName,
        'profession': profession,
        'userName': userName,
        'email': email,
        'nationality': nationality,
        'currency': currency,
        'selectedPrograms': selectedPrograms,
        'preferences': preferences,
      };

  factory SignupProfileData.fromJson(Map<String, dynamic> json) {
    return SignupProfileData(
      fullName: (json['fullName'] as String?) ?? '',
      profession: (json['profession'] as String?) ?? '',
      userName: (json['userName'] as String?) ?? '',
      email: (json['email'] as String?) ?? '',
      nationality: (json['nationality'] as String?) ?? 'India',
      currency: (json['currency'] as String?) ?? '₹',
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
  static Future<void> saveProfile(SignupProfileData data) async {
    final jsonMap = data.toJson();
    await UserFirestoreSync.instance.patchSettingsNow({'signupProfile': jsonMap});
  }

  static Future<SignupProfileData?> getProfile() async {
    final settings = await UserFirestoreSync.instance.loadSettings();
    final raw = settings?['signupProfile'];
    if (raw is Map<String, dynamic>) return SignupProfileData.fromJson(raw);
    if (raw is Map) {
      return SignupProfileData.fromJson(Map<String, dynamic>.from(raw));
    }
    return null;
  }

  static Future<void> clear() async {
    await UserFirestoreSync.instance.patchSettingsNow({'signupProfile': null});
  }
}
