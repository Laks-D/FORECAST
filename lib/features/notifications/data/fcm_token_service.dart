import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';

import 'fcm_token_repository.dart';

/// Registers the current device's FCM token under the signed-in user and keeps
/// it fresh on rotation. Fully guarded: any failure (unsupported platform,
/// permission denied, no token) is swallowed so it can never break sign-in.
///
/// Call [registerCurrentDevice] after authentication succeeds.
class FcmTokenService {
  FcmTokenService._();
  static final FcmTokenService instance = FcmTokenService._();

  final FcmTokenRepository _repo = FirestoreFcmTokenRepository();
  String? _registeredUid;
  bool _refreshHooked = false;

  String get _platform => kIsWeb ? 'web' : defaultTargetPlatform.name;

  Future<void> registerCurrentDevice() async {
    try {
      final uid = FirebaseAuth.instance.currentUser?.uid;
      if (uid == null || uid.isEmpty) return;
      if (uid == _registeredUid) return; // already done this session

      final token = await FirebaseMessaging.instance.getToken();
      if (token == null || token.isEmpty) return;

      await _repo.saveToken(uid: uid, token: token, platform: _platform);
      _registeredUid = uid;

      if (!_refreshHooked) {
        _refreshHooked = true;
        FirebaseMessaging.instance.onTokenRefresh.listen((t) {
          final u = FirebaseAuth.instance.currentUser?.uid;
          if (u != null && u.isNotEmpty) {
            _repo.saveToken(uid: u, token: t, platform: _platform);
          }
        });
      }
    } catch (_) {
      // Non-critical — local notifications remain the primary path.
    }
  }

  /// Forget the cached uid (call on sign-out so the next user re-registers).
  void reset() => _registeredUid = null;
}
