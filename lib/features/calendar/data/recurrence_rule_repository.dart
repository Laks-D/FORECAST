import 'package:cloud_firestore/cloud_firestore.dart';

import '../../../core/app/target_uid_resolver.dart';
import '../domain/entities/recurrence_rule.dart';

/// Abstraction over the `recurrence_rules` sub-collection.
abstract class RecurrenceRuleRepository {
  Future<List<RecurrenceRule>> getAll();
  Future<RecurrenceRule?> getById(String recurrenceId);
  Future<void> upsert(RecurrenceRule rule);
  Future<void> delete(String recurrenceId);
}

class FirestoreRecurrenceRuleRepository implements RecurrenceRuleRepository {
  FirestoreRecurrenceRuleRepository({
    FirebaseFirestore? firestore,
    TargetUidProvider? targetUid,
  })  : _db = firestore ?? FirebaseFirestore.instance,
        _targetUid = targetUid ?? defaultTargetUid;

  final FirebaseFirestore _db;
  final TargetUidProvider _targetUid;

  Future<CollectionReference<Map<String, dynamic>>?> _col() async {
    final uid = await _targetUid();
    if (uid == null || uid.trim().isEmpty) return null;
    return _db.collection('users').doc(uid).collection('recurrence_rules');
  }

  @override
  Future<List<RecurrenceRule>> getAll() async {
    final col = await _col();
    if (col == null) return const [];
    final snap = await col.get();
    return snap.docs
        .map((d) =>
            RecurrenceRule.fromJson(Map<String, dynamic>.from(d.data()), id: d.id))
        .toList(growable: false);
  }

  @override
  Future<RecurrenceRule?> getById(String recurrenceId) async {
    final col = await _col();
    if (col == null) return null;
    final doc = await col.doc(recurrenceId).get();
    if (!doc.exists) return null;
    return RecurrenceRule.fromJson(Map<String, dynamic>.from(doc.data()!),
        id: doc.id);
  }

  @override
  Future<void> upsert(RecurrenceRule rule) async {
    final col = await _col();
    if (col == null) return;
    await col.doc(rule.recurrenceId).set({
      ...rule.toJson(),
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  @override
  Future<void> delete(String recurrenceId) async {
    final col = await _col();
    if (col == null) return;
    await col.doc(recurrenceId).delete();
  }
}

class InMemoryRecurrenceRuleRepository implements RecurrenceRuleRepository {
  final Map<String, RecurrenceRule> _store = {};

  @override
  Future<List<RecurrenceRule>> getAll() async =>
      _store.values.toList(growable: false);

  @override
  Future<RecurrenceRule?> getById(String recurrenceId) async =>
      _store[recurrenceId];

  @override
  Future<void> upsert(RecurrenceRule rule) async {
    _store[rule.recurrenceId] = rule;
  }

  @override
  Future<void> delete(String recurrenceId) async {
    _store.remove(recurrenceId);
  }
}
