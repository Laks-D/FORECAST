import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../../../core/app/target_uid_resolver.dart';
import '../domain/entities/client.dart';
import '../domain/repositories/client_repository.dart';

class FirestoreClientRepository implements ClientRepository {
  FirestoreClientRepository({
    FirebaseFirestore? firestore,
    TargetUidProvider? targetUid,
  })  : _db = firestore ?? FirebaseFirestore.instance,
        _targetUid = targetUid ?? defaultTargetUid;

  final FirebaseFirestore _db;
  final TargetUidProvider _targetUid;

  Future<CollectionReference<Map<String, dynamic>>?> _col({bool deleted = false}) async {
    final uid = await _targetUid();
    if (uid == null || uid.trim().isEmpty) return null;
    return _db.collection('users').doc(uid).collection(deleted ? 'deleted_clients' : 'clients');
  }

  List<Client> _map(QuerySnapshot<Map<String, dynamic>> snap) => snap.docs
      .map((d) => Client.fromJson(<String, dynamic>{...d.data(), 'id': d.id}))
      .toList(growable: false);

  @override
  Stream<List<Client>> watchClients() async* {
    // Wait for Firebase Auth to initialise so that _col() returns a valid
    // reference even on cold start.  Without this the stream would yield []
    // once and close permanently.
    await FirebaseAuth.instance.authStateChanges().first;
    final col = await _col();
    if (col == null) {
      yield const [];
      return;
    }
    yield* col.snapshots().map(_map);
  }

  @override
  Future<List<Client>> getClients() async {
    final col = await _col();
    if (col == null) return const [];
    final snap = await col.get();
    return _map(snap);
  }

  @override
  Future<List<Client>> getDeletedClients() async {
    final col = await _col(deleted: true);
    if (col == null) return const [];
    final snap = await col.get();
    return _map(snap);
  }

  @override
  Future<void> addClient(Client client) async {
    final col = await _col();
    if (col == null) return;
    final json = client.toJson();
    json['createdAt'] = FieldValue.serverTimestamp();
    json['updatedAt'] = FieldValue.serverTimestamp();
    await col.doc(client.id).set(json, SetOptions(merge: true));
  }

  @override
  Future<void> updateClient(Client client) async {
    final col = await _col();
    if (col == null) return;
    final json = client.toJson();
    json['updatedAt'] = FieldValue.serverTimestamp();
    await col.doc(client.id).set(json, SetOptions(merge: true));
  }

  @override
  Future<void> deleteClient({required String entityId}) async {
    final col = await _col();
    final delCol = await _col(deleted: true);
    if (col == null || delCol == null) return;

    final doc = await col.doc(entityId).get();
    if (!doc.exists) return;

    final json = Map<String, dynamic>.from(doc.data()!);
    json['deletedAt'] = FieldValue.serverTimestamp();
    
    final batch = _db.batch();
    batch.set(delCol.doc(entityId), json, SetOptions(merge: true));
    batch.delete(col.doc(entityId));
    await batch.commit();
  }

  @override
  Future<void> restoreClient({required String entityId}) async {
    final col = await _col();
    final delCol = await _col(deleted: true);
    if (col == null || delCol == null) return;

    final doc = await delCol.doc(entityId).get();
    if (!doc.exists) return;

    final json = Map<String, dynamic>.from(doc.data()!);
    json.remove('deletedAt');
    
    final batch = _db.batch();
    batch.set(col.doc(entityId), json, SetOptions(merge: true));
    batch.delete(delCol.doc(entityId));
    await batch.commit();
  }

  @override
  Future<void> permanentlyDeleteClient({required String entityId}) async {
    final delCol = await _col(deleted: true);
    if (delCol == null) return;
    await delCol.doc(entityId).delete();
  }

  @override
  Future<void> loadFromStorage() async {
    // No-op for Firestore. Streams load automatically.
  }

  @override
  Future<void> persist() async {
    // No-op for Firestore. Writes happen immediately.
  }
}
