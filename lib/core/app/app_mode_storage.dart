import 'package:shared_preferences/shared_preferences.dart';

import 'app_mode.dart';

class AppModeStorage {
  static const _key = 'app_mode_v1';

  /// Returns `null` when the user has not chosen a mode yet.
  static Future<AppMode?> load() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = (prefs.getString(_key) ?? '').trim();
    if (raw.isEmpty) return null;

    for (final m in AppMode.values) {
      if (m.name == raw) return m;
    }
    return null;
  }

  static Future<void> save(AppMode mode) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_key, mode.name);
  }
}
