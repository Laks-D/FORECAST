import '../services/user_firestore_sync.dart';
import 'app_role.dart';

class AppRoleStorage {
  static Future<AppRole> load() async {
    final settings = await UserFirestoreSync.instance.loadSettings();
    final raw = (settings?['appRole'] as String? ?? '').trim();

    if (raw.isEmpty) return AppRole.tutor;

    return AppRole.values.firstWhere(
      (e) => e.name == raw,
      orElse: () => AppRole.tutor,
    );
  }

  static Future<void> save(AppRole role) async {
    await UserFirestoreSync.instance.patchSettingsNow({'appRole': role.name});
  }
}
