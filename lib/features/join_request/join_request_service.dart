import 'package:cloud_firestore/cloud_firestore.dart';

import '../../core/firebase/firestore_db.dart';
import 'join_request_model.dart';

/// Service for all Firestore operations on the `join_requests` collection.
///
/// The QR code contains a `ts` (timestamp in ms-since-epoch) field.
/// Any request whose QR was generated more than [_kExpireMinutes] ago is
/// rejected on the client side before even writing to Firestore.
class JoinRequestService {
  JoinRequestService._();

  static const _kCollection = 'join_requests';
  static const _kExpireMinutes = 15;

  // ── CLIENT SIDE ──────────────────────────────────────────────────────────

  /// Returns `true` if the QR timestamp [tsMs] (milliseconds since epoch as
  /// a string) is still within the [_kExpireMinutes] expiry window.
  static bool isQrValid(String? tsMs) {
    if (tsMs == null) return false;
    final ms = int.tryParse(tsMs);
    if (ms == null) return false;
    final qrTime = DateTime.fromMillisecondsSinceEpoch(ms);
    return DateTime.now().difference(qrTime).inMinutes < _kExpireMinutes;
  }

  /// Writes a new join-request document and returns the generated doc ID.
  static Future<String> sendRequest({
    required String orgId,
    required String clientFirebaseUid,
    required String clientName,
    required String clientPhone,
  }) async {
    final ref = firestoreDb.collection(_kCollection).doc();
    await ref.set({
      'orgId': orgId,
      'clientFirebaseUid': clientFirebaseUid,
      'clientName': clientName,
      'clientPhone': clientPhone,
      'status': 'pending',
      'createdAt': FieldValue.serverTimestamp(),
      'resolvedAt': null,
    });
    return ref.id;
  }

  /// Stream of the `status` field for a specific request document.
  /// Emits `pending`, `accepted`, or `rejected` as the admin acts.
  static Stream<String> watchStatus(String docId) {
    return firestoreDb
        .collection(_kCollection)
        .doc(docId)
        .snapshots()
        .map((snap) => (snap.data()?['status'] as String?) ?? 'pending');
  }

  // ── ADMIN SIDE ────────────────────────────────────────────────────────────

  /// Stream of all pending join requests for a given organization.
  static Stream<List<JoinRequestModel>> watchPendingForOrg(String orgId) {
    return firestoreDb
        .collection(_kCollection)
        .where('orgId', isEqualTo: orgId)
        .where('status', isEqualTo: 'pending')
        .orderBy('createdAt', descending: false)
        .snapshots()
        .map((snap) => snap.docs
            .map((d) => JoinRequestModel.fromFirestore(d.id, d.data()))
            .toList());
  }

  /// Admin resolves a request by writing `accepted` or `rejected`.
  static Future<void> resolve(String docId, String status) async {
    assert(status == 'accepted' || status == 'rejected');
    await firestoreDb.collection(_kCollection).doc(docId).update({
      'status': status,
      'resolvedAt': FieldValue.serverTimestamp(),
    });

    if (status != 'accepted') return;

    // On acceptance, enroll the client into the org's students collection.
    final reqSnap = await firestoreDb.collection(_kCollection).doc(docId).get();
    final data = reqSnap.data();
    if (data == null) return;

    final orgId = (data['orgId'] as String?) ?? '';
    if (orgId.isEmpty) return;

    await firestoreDb
        .collection('organizations')
        .doc(orgId)
        .collection('students')
        .add({
      'orgId': orgId,
      'fullName': (data['clientName'] as String?) ?? 'Client',
      'phone': (data['clientPhone'] as String?) ?? '',
      'profession': '',
      'enrolledBy': (data['clientFirebaseUid'] as String?) ?? '',
      'status': 'enrolled',
      'joinedVia': 'qr_request',
      'joinRequestId': docId,
      'createdAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  /// Resolves the org ID for a given tutor/admin Firebase UID by querying
  /// the `organizations` collection (existing pattern used throughout the app).
  static Future<String?> resolveOrgId(String tutorUid) async {
    try {
      final snap = await firestoreDb
          .collection('organizations')
          .where('ownerId', isEqualTo: tutorUid)
          .limit(1)
          .get();
      if (snap.docs.isNotEmpty) return snap.docs.first.id;
    } catch (_) {}
    return null;
  }
}
