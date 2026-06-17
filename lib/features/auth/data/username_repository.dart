import 'package:cloud_firestore/cloud_firestore.dart';

import '../../../core/auth/username_key.dart';
import '../../../core/firebase/firestore_db.dart';

/// Maps a normalized username -> uid via the top-level `usernames` collection.
///
/// Intentionally stores NO email/PII (per docs/FIRESTORE_SCHEMA.md guidance and
/// the firestore.rules `usernames` field allow-list). Resolves only uid, so a
/// username can identify an account without exposing contact data.
abstract class UsernameRepository {
  /// Best-effort claim of [username] for [uid]. Never throws on collision —
  /// the auth signup path must not break if a username is already taken.
  Future<void> register({required String uid, required String username});

  /// Resolve the uid that owns [username], or null.
  Future<String?> resolveUid(String username);
}

class FirestoreUsernameRepository implements UsernameRepository {
  FirestoreUsernameRepository({FirebaseFirestore? firestore})
      : _db = firestore ?? firestoreDb;

  final FirebaseFirestore _db;

  CollectionReference<Map<String, dynamic>> get _col =>
      _db.collection('usernames');

  @override
  Future<void> register({required String uid, required String username}) async {
    final key = usernameKeyFromInput(username);
    if (key.isEmpty) return;
    try {
      final existing = await _col.doc(key).get();
      if (existing.exists) return; // already claimed — leave it
      await _col.doc(key).set({
        'uid': uid,
        'username': key,
        'createdAt': FieldValue.serverTimestamp(),
      });
    } catch (_) {
      // Swallow: username mapping is non-critical convenience.
    }
  }

  @override
  Future<String?> resolveUid(String username) async {
    final key = usernameKeyFromInput(username);
    if (key.isEmpty) return null;
    try {
      final snap = await _col.doc(key).get();
      return snap.data()?['uid'] as String?;
    } catch (_) {
      return null;
    }
  }
}

/// In-memory fake for tests.
class InMemoryUsernameRepository implements UsernameRepository {
  final Map<String, String> _byKey = {}; // key -> uid

  @override
  Future<void> register({required String uid, required String username}) async {
    final key = usernameKeyFromInput(username);
    if (key.isEmpty) return;
    _byKey.putIfAbsent(key, () => uid);
  }

  @override
  Future<String?> resolveUid(String username) async =>
      _byKey[usernameKeyFromInput(username)];
}
