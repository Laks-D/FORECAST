import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../../../core/firebase/firestore_db.dart';
import '../../../core/services/notification_storage.dart';

/// Per-user notification history stored at `users/{uid}/notifications/{id}`.
///
/// Replaces the legacy `notificationRecords[]` array embedded in the settings
/// doc. Owner is always the signed-in user (self), so the uid resolver defaults
/// to the current Firebase user.
abstract class NotificationRecordRepository {
  Future<void> upsert(AppNotification record);
  Future<void> upsertAll(List<AppNotification> records);
  Future<List<AppNotification>> getAll();
  Stream<List<AppNotification>> watchAll();
  Future<void> markRead(String id);
  Future<void> delete(String id);
}

class FirestoreNotificationRecordRepository
    implements NotificationRecordRepository {
  FirestoreNotificationRecordRepository({
    FirebaseFirestore? firestore,
    Future<String?> Function()? uid,
  })  : _db = firestore ?? firestoreDb,
        _uid = uid ?? (() async => FirebaseAuth.instance.currentUser?.uid);

  final FirebaseFirestore _db;
  final Future<String?> Function() _uid;

  Future<CollectionReference<Map<String, dynamic>>?> _col() async {
    final uid = await _uid();
    if (uid == null || uid.trim().isEmpty) return null;
    return _db.collection('users').doc(uid).collection('notifications');
  }

  @override
  Future<void> upsert(AppNotification record) async {
    final col = await _col();
    if (col == null) return;
    await col.doc(record.id).set({
      ...record.toJson(),
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  @override
  Future<void> upsertAll(List<AppNotification> records) async {
    final col = await _col();
    if (col == null) return;
    final batch = _db.batch();
    for (final r in records) {
      batch.set(col.doc(r.id), {
        ...r.toJson(),
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
    }
    await batch.commit();
  }

  @override
  Future<List<AppNotification>> getAll() async {
    final col = await _col();
    if (col == null) return const [];
    final snap = await col.get();
    final list = snap.docs
        .map((d) => AppNotification.fromJson(Map<String, dynamic>.from(d.data())))
        .toList();
    list.sort((a, b) => b.createdAt.compareTo(a.createdAt));
    return list;
  }

  @override
  Stream<List<AppNotification>> watchAll() async* {
    final col = await _col();
    if (col == null) {
      yield const [];
      return;
    }
    yield* col.snapshots().map((s) {
      final list = s.docs
          .map((d) =>
              AppNotification.fromJson(Map<String, dynamic>.from(d.data())))
          .toList();
      list.sort((a, b) => b.createdAt.compareTo(a.createdAt));
      return list;
    });
  }

  @override
  Future<void> markRead(String id) async {
    final col = await _col();
    if (col == null) return;
    await col.doc(id).set({'read': true}, SetOptions(merge: true));
  }

  @override
  Future<void> delete(String id) async {
    final col = await _col();
    if (col == null) return;
    await col.doc(id).delete();
  }
}

class InMemoryNotificationRecordRepository
    implements NotificationRecordRepository {
  final Map<String, AppNotification> _store = {};

  @override
  Future<void> upsert(AppNotification record) async {
    _store[record.id] = record;
  }

  @override
  Future<void> upsertAll(List<AppNotification> records) async {
    for (final r in records) {
      _store[r.id] = r;
    }
  }

  @override
  Future<List<AppNotification>> getAll() async {
    final list = _store.values.toList();
    list.sort((a, b) => b.createdAt.compareTo(a.createdAt));
    return list;
  }

  @override
  Stream<List<AppNotification>> watchAll() async* {
    yield await getAll();
  }

  @override
  Future<void> markRead(String id) async {
    final r = _store[id];
    if (r != null) _store[id] = r.copyWith(read: true);
  }

  @override
  Future<void> delete(String id) async {
    _store.remove(id);
  }
}
