import 'package:cloud_firestore/cloud_firestore.dart';

import '../../../core/firebase/firestore_db.dart';

/// Persists FCM device registration tokens at
/// `users/{uid}/fcmTokens/{token}` so server-side / cross-device push can
/// target a user's devices. (The app currently uses local notifications, but
/// populating this table re-enables remote push without a schema change.)
abstract class FcmTokenRepository {
  Future<void> saveToken({
    required String uid,
    required String token,
    required String platform,
  });

  Future<List<String>> getTokens(String uid);

  Future<void> deleteToken({required String uid, required String token});
}

class FirestoreFcmTokenRepository implements FcmTokenRepository {
  FirestoreFcmTokenRepository({FirebaseFirestore? firestore})
      : _db = firestore ?? firestoreDb;

  final FirebaseFirestore _db;

  CollectionReference<Map<String, dynamic>> _col(String uid) =>
      _db.collection('users').doc(uid).collection('fcmTokens');

  @override
  Future<void> saveToken({
    required String uid,
    required String token,
    required String platform,
  }) async {
    if (uid.isEmpty || token.isEmpty) return;
    try {
      await _col(uid).doc(token).set({
        'token': token,
        'platform': platform,
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
    } catch (_) {
      // Non-critical.
    }
  }

  @override
  Future<List<String>> getTokens(String uid) async {
    try {
      final snap = await _col(uid).get();
      return snap.docs.map((d) => d.id).toList(growable: false);
    } catch (_) {
      return const [];
    }
  }

  @override
  Future<void> deleteToken({required String uid, required String token}) async {
    try {
      await _col(uid).doc(token).delete();
    } catch (_) {}
  }
}

class InMemoryFcmTokenRepository implements FcmTokenRepository {
  final Map<String, Map<String, String>> _byUid = {}; // uid -> token -> platform

  @override
  Future<void> saveToken({
    required String uid,
    required String token,
    required String platform,
  }) async {
    (_byUid[uid] ??= {})[token] = platform;
  }

  @override
  Future<List<String>> getTokens(String uid) async =>
      _byUid[uid]?.keys.toList(growable: false) ?? const [];

  @override
  Future<void> deleteToken({required String uid, required String token}) async {
    _byUid[uid]?.remove(token);
  }
}
