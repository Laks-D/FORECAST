import 'package:shared_preferences/shared_preferences.dart';

import 'app_role.dart';

class AppRoleStorage {
  static const _key = 'app_role_v1';

  static Future<AppRole> load() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = (prefs.getString(_key) ?? '').trim();

    if (raw.isEmpty) return AppRole.tutor;

    return AppRole.values.firstWhere(
      (e) => e.name == raw,
      orElse: () => AppRole.tutor,
    );
  }

  static Future<void> save(AppRole role) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_key, role.name);
  }
}
