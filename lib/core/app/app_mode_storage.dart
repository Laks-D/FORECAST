import '../services/user_firestore_sync.dart';
import 'app_mode.dart';

class AppModeStorage {
  /// Returns `null` when the user has not chosen a mode yet.
  static Future<AppMode?> load() async {
    final settings = await UserFirestoreSync.instance.loadSettings();
    final raw = (settings?['appMode'] as String? ?? '').trim();
    if (raw.isEmpty) return null;

    for (final m in AppMode.values) {
      if (m.name == raw) return m;
    }
    return null;
  }

  static Future<void> save(AppMode mode) async {
    await UserFirestoreSync.instance.patchSettingsNow({'appMode': mode.name});
  }
}
