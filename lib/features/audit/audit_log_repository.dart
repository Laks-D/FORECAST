import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../../core/firebase/firestore_db.dart';
import 'audit_entry.dart';

/// Append-only audit log under `users/{actorUid}/audit_log`.
abstract class AuditLogRepository {
  Future<void> append(AuditEntry entry);
  Future<List<AuditEntry>> getRecent({int limit = 100});
}

class FirestoreAuditLogRepository implements AuditLogRepository {
  FirestoreAuditLogRepository({
    FirebaseFirestore? firestore,
    Future<String?> Function()? actorUid,
  })  : _db = firestore ?? firestoreDb,
        _actorUid =
            actorUid ?? (() async => FirebaseAuth.instance.currentUser?.uid);

  final FirebaseFirestore _db;
  final Future<String?> Function() _actorUid;

  Future<CollectionReference<Map<String, dynamic>>?> _col() async {
    final uid = await _actorUid();
    if (uid == null || uid.trim().isEmpty) return null;
    return _db.collection('users').doc(uid).collection('audit_log');
  }

  @override
  Future<void> append(AuditEntry entry) async {
    final col = await _col();
    if (col == null) return;
    await col.doc(entry.logId).set({
      ...entry.toJson(),
      'at': FieldValue.serverTimestamp(),
    });
  }

  @override
  Future<List<AuditEntry>> getRecent({int limit = 100}) async {
    final col = await _col();
    if (col == null) return const [];
    final snap = await col.limit(limit).get();
    final list = snap.docs
        .map((d) =>
            AuditEntry.fromJson(Map<String, dynamic>.from(d.data()), id: d.id))
        .toList();
    list.sort((a, b) =>
        (b.at ?? DateTime(1970)).compareTo(a.at ?? DateTime(1970)));
    return list;
  }
}

class InMemoryAuditLogRepository implements AuditLogRepository {
  final List<AuditEntry> entries = [];

  @override
  Future<void> append(AuditEntry entry) async => entries.add(entry);

  @override
  Future<List<AuditEntry>> getRecent({int limit = 100}) async =>
      entries.reversed.take(limit).toList();
}
