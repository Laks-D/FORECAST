import 'package:cloud_firestore/cloud_firestore.dart';

import '../../../core/app/target_uid_resolver.dart';
import '../domain/entities/client_event.dart';

/// Abstraction over the `client_events` sub-collection (notes / status changes
/// / profile-created). Payments are NOT stored here.
abstract class ClientEventRepository {
  /// TUTOR-side read (owner): filter by clientId.
  Future<List<ClientEvent>> getForClient(String clientId);
  Stream<List<ClientEvent>> watchForClient(String clientId);

  /// STUDENT-side read: must filter by `firebaseUid` to satisfy the rule that
  /// scopes an enrolled student's read by their own denormalized uid.
  Future<List<ClientEvent>> getForStudent(String firebaseUid);

  Future<void> add(ClientEvent event);
  Future<void> delete(String eventId);
}

class FirestoreClientEventRepository implements ClientEventRepository {
  FirestoreClientEventRepository({
    FirebaseFirestore? firestore,
    TargetUidProvider? targetUid,
  })  : _db = firestore ?? FirebaseFirestore.instance,
        _targetUid = targetUid ?? defaultTargetUid;

  final FirebaseFirestore _db;
  final TargetUidProvider _targetUid;

  Future<CollectionReference<Map<String, dynamic>>?> _col() async {
    final uid = await _targetUid();
    if (uid == null || uid.trim().isEmpty) return null;
    return _db.collection('users').doc(uid).collection('client_events');
  }

  List<ClientEvent> _map(QuerySnapshot<Map<String, dynamic>> s) {
    final list = s.docs
        .map((d) =>
            ClientEvent.fromJson(Map<String, dynamic>.from(d.data()), id: d.id))
        .toList();
    list.sort((a, b) => a.createdAt.compareTo(b.createdAt));
    return list;
  }

  @override
  Future<List<ClientEvent>> getForClient(String clientId) async {
    final col = await _col();
    if (col == null) return const [];
    return _map(await col.where('clientId', isEqualTo: clientId).get());
  }

  @override
  Stream<List<ClientEvent>> watchForClient(String clientId) async* {
    final col = await _col();
    if (col == null) {
      yield const [];
      return;
    }
    yield* col.where('clientId', isEqualTo: clientId).snapshots().map(_map);
  }

  @override
  Future<List<ClientEvent>> getForStudent(String firebaseUid) async {
    final col = await _col();
    if (col == null) return const [];
    return _map(await col.where('firebaseUid', isEqualTo: firebaseUid).get());
  }

  @override
  Future<void> add(ClientEvent event) async {
    final col = await _col();
    if (col == null) return;
    await col.doc(event.eventId).set({
      ...event.toJson(),
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  @override
  Future<void> delete(String eventId) async {
    final col = await _col();
    if (col == null) return;
    await col.doc(eventId).delete();
  }
}

class InMemoryClientEventRepository implements ClientEventRepository {
  final Map<String, ClientEvent> _store = {};

  @override
  Future<List<ClientEvent>> getForClient(String clientId) async {
    final list =
        _store.values.where((e) => e.clientId == clientId).toList();
    list.sort((a, b) => a.createdAt.compareTo(b.createdAt));
    return list;
  }

  @override
  Stream<List<ClientEvent>> watchForClient(String clientId) async* {
    yield await getForClient(clientId);
  }

  @override
  Future<List<ClientEvent>> getForStudent(String firebaseUid) async {
    final list =
        _store.values.where((e) => e.firebaseUid == firebaseUid).toList();
    list.sort((a, b) => a.createdAt.compareTo(b.createdAt));
    return list;
  }

  @override
  Future<void> add(ClientEvent event) async {
    _store[event.eventId] = event;
  }

  @override
  Future<void> delete(String eventId) async {
    _store.remove(eventId);
  }
}
