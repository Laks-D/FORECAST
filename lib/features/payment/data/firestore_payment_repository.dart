import 'package:cloud_firestore/cloud_firestore.dart';

import '../../../core/app/target_uid_resolver.dart';
import '../domain/entities/payment.dart';
import '../domain/repositories/payment_repository.dart';
import '../../../core/app/app_mode.dart';
import 'package:firebase_auth/firebase_auth.dart';

/// Cloud Firestore implementation of [PaymentRepository].
///
/// Stores docs at `users/{targetUid}/payments/{paymentId}`. The [targetUid]
/// callback resolves the owning tutor uid (own uid for tutors, enrolled tutor
/// uid for students), and [firestore] is injectable so the repository is
/// unit-testable with `fake_cloud_firestore`.
class FirestorePaymentRepository implements PaymentRepository {
  FirestorePaymentRepository({
    FirebaseFirestore? firestore,
    TargetUidProvider? targetUid,
  })  : _db = firestore ?? FirebaseFirestore.instance,
        _targetUid = targetUid ?? defaultTargetUid;

  final FirebaseFirestore _db;
  final TargetUidProvider _targetUid;

  Future<CollectionReference<Map<String, dynamic>>?> _col() async {
    final uid = await _targetUid();
    if (uid == null || uid.trim().isEmpty) return null;
    return _db.collection('users').doc(uid).collection('payments');
  }

  List<Payment> _map(QuerySnapshot<Map<String, dynamic>> snap) => snap.docs
      .map((d) => Payment.fromJson(Map<String, dynamic>.from(d.data()), id: d.id))
      .toList(growable: false);

  @override
  Future<List<Payment>> getForClient(String clientId) async {
    final col = await _col();
    if (col == null) return const [];
    final snap = await col.where('clientId', isEqualTo: clientId).get();
    final list = _map(snap);
    list.sort((a, b) => b.dueDate.compareTo(a.dueDate));
    return list;
  }

  @override
  Stream<List<Payment>> watchForClient(String clientId) async* {
    final col = await _col();
    if (col == null) {
      yield const [];
      return;
    }
    yield* col.where('clientId', isEqualTo: clientId).snapshots().map((s) {
      final list = _map(s);
      list.sort((a, b) => b.dueDate.compareTo(a.dueDate));
      return list;
    });
  }

  @override
  Future<List<Payment>> getForStudent(String firebaseUid) async {
    final col = await _col();
    if (col == null) return const [];
    final snap = await col.where('firebaseUid', isEqualTo: firebaseUid).get();
    final list = _map(snap);
    list.sort((a, b) => b.dueDate.compareTo(a.dueDate));
    return list;
  }

  @override
  Stream<List<Payment>> watchForStudent(String firebaseUid) async* {
    final col = await _col();
    if (col == null) {
      yield const [];
      return;
    }
    yield* col.where('firebaseUid', isEqualTo: firebaseUid).snapshots().map((s) {
      final list = _map(s);
      list.sort((a, b) => b.dueDate.compareTo(a.dueDate));
      return list;
    });
  }

  @override
  Future<List<Payment>> getAll() async {
    final col = await _col();
    if (col == null) return const [];
    Query<Map<String, dynamic>> query = col;
    if (AppModeConfig.isClient) {
      final userUid = FirebaseAuth.instance.currentUser?.uid;
      if (userUid != null) {
        query = query.where('firebaseUid', isEqualTo: userUid);
      } else {
        return const [];
      }
    }
    final snap = await query.get();
    final list = _map(snap);
    list.sort((a, b) => a.dueDate.compareTo(b.dueDate));
    return list;
  }

  @override
  Stream<List<Payment>> watchAll() async* {
    final col = await _col();
    if (col == null) {
      yield const [];
      return;
    }
    Query<Map<String, dynamic>> query = col;
    if (AppModeConfig.isClient) {
      final userUid = FirebaseAuth.instance.currentUser?.uid;
      if (userUid != null) {
        query = query.where('firebaseUid', isEqualTo: userUid);
      } else {
        yield const [];
        return;
      }
    }
    yield* query.snapshots().map((s) {
      final list = _map(s);
      list.sort((a, b) => a.dueDate.compareTo(b.dueDate));
      return list;
    });
  }

  @override
  Future<void> add(Payment payment) async {
    final col = await _col();
    if (col == null) return;
    final json = payment.toJson();
    json['createdAt'] = FieldValue.serverTimestamp();
    json['updatedAt'] = FieldValue.serverTimestamp();
    await col.doc(payment.paymentId).set(json, SetOptions(merge: true));
  }

  @override
  Future<void> update(Payment payment) async {
    final col = await _col();
    if (col == null) return;
    final json = payment.toJson();
    json['updatedAt'] = FieldValue.serverTimestamp();
    await col.doc(payment.paymentId).set(json, SetOptions(merge: true));
  }

  @override
  Future<void> delete(String paymentId) async {
    final col = await _col();
    if (col == null) return;
    await col.doc(paymentId).delete();
  }

  @override
  Future<void> markPaid(String paymentId,
      {DateTime? paidDate, String? method}) async {
    final col = await _col();
    if (col == null) return;
    final d = paidDate ?? DateTime.now();
    await col.doc(paymentId).set({
      'status': PaymentStatus.paid.name,
      'paidDate':
          '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}',
      if (method != null) 'method': method,
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  @override
  Future<void> setStatus(String paymentId, PaymentStatus status) async {
    final col = await _col();
    if (col == null) return;
    await col.doc(paymentId).set({
      'status': status.name,
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }
}
