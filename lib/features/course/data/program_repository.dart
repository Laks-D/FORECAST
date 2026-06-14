import 'package:cloud_firestore/cloud_firestore.dart';

import '../../../core/app/target_uid_resolver.dart';
import '../domain/entities/program.dart';

/// Abstraction over the `programs` sub-collection.
abstract class ProgramRepository {
  Future<List<Program>> getAll();
  Stream<List<Program>> watchAll();
  Future<void> upsert(Program program);

  /// Replace the full set: upsert everything in [programs] and delete any doc
  /// no longer present. Used by the dual-write mirror of the legacy array.
  Future<void> replaceAll(List<Program> programs);

  Future<void> delete(String programId);
}

class FirestoreProgramRepository implements ProgramRepository {
  FirestoreProgramRepository({
    FirebaseFirestore? firestore,
    TargetUidProvider? targetUid,
  })  : _db = firestore ?? FirebaseFirestore.instance,
        _targetUid = targetUid ?? defaultTargetUid;

  final FirebaseFirestore _db;
  final TargetUidProvider _targetUid;

  Future<CollectionReference<Map<String, dynamic>>?> _col() async {
    final uid = await _targetUid();
    if (uid == null || uid.trim().isEmpty) return null;
    return _db.collection('users').doc(uid).collection('programs');
  }

  List<Program> _map(QuerySnapshot<Map<String, dynamic>> s) {
    final list = s.docs
        .map((d) => Program.fromJson(Map<String, dynamic>.from(d.data()), id: d.id))
        .toList();
    list.sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
    return list;
  }

  @override
  Future<List<Program>> getAll() async {
    final col = await _col();
    if (col == null) return const [];
    return _map(await col.get());
  }

  @override
  Stream<List<Program>> watchAll() async* {
    final col = await _col();
    if (col == null) {
      yield const [];
      return;
    }
    yield* col.snapshots().map(_map);
  }

  @override
  Future<void> upsert(Program program) async {
    final col = await _col();
    if (col == null) return;
    await col.doc(program.programId).set({
      ...program.toJson(),
      'createdAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  @override
  Future<void> replaceAll(List<Program> programs) async {
    final col = await _col();
    if (col == null) return;
    final keepIds = programs.map((p) => p.programId).toSet();
    final existing = await col.get();
    final batch = _db.batch();
    for (final doc in existing.docs) {
      if (!keepIds.contains(doc.id)) batch.delete(doc.reference);
    }
    for (final p in programs) {
      batch.set(col.doc(p.programId), {
        ...p.toJson(),
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
    }
    await batch.commit();
  }

  @override
  Future<void> delete(String programId) async {
    final col = await _col();
    if (col == null) return;
    await col.doc(programId).delete();
  }
}

class InMemoryProgramRepository implements ProgramRepository {
  final Map<String, Program> _store = {};

  @override
  Future<List<Program>> getAll() async {
    final list = _store.values.toList();
    list.sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
    return list;
  }

  @override
  Stream<List<Program>> watchAll() async* {
    yield await getAll();
  }

  @override
  Future<void> upsert(Program program) async {
    _store[program.programId] = program;
  }

  @override
  Future<void> replaceAll(List<Program> programs) async {
    final keep = programs.map((p) => p.programId).toSet();
    _store.removeWhere((k, _) => !keep.contains(k));
    for (final p in programs) {
      _store[p.programId] = p;
    }
  }

  @override
  Future<void> delete(String programId) async {
    _store.remove(programId);
  }
}
