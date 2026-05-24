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
    required String tutorId,
    required String clientFirebaseUid,
    required String clientName,
    required String clientPhone,
  }) async {
    final ref = firestoreDb.collection(_kCollection).doc();
    await ref.set({
      'tutorId': tutorId,
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

  /// Stream of all pending join requests for a given tutor.
  static Stream<List<JoinRequestModel>> watchPendingForTutor(String tutorId) {
    return firestoreDb
        .collection(_kCollection)
        .where('tutorId', isEqualTo: tutorId)
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

    // On acceptance, enroll the client into the tutor's students collection.
    final reqSnap = await firestoreDb.collection(_kCollection).doc(docId).get();
    final data = reqSnap.data();
    if (data == null) return;

    final tutorId = (data['tutorId'] as String?) ?? '';
    final studentUid = (data['clientFirebaseUid'] as String?) ?? '';
    if (tutorId.isEmpty) return;

    await firestoreDb
        .collection('users')
        .doc(tutorId)
        .collection('students')
        .add({
      'tutorId': tutorId,
      'fullName': (data['clientName'] as String?) ?? 'Client',
      'phone': (data['clientPhone'] as String?) ?? '',
      'profession': '',
      'enrolledBy': studentUid,
      'status': 'enrolled',
      'joinedVia': 'qr_request',
      'joinRequestId': docId,
      'createdAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    });

    // Write enrollment record to the student's own user doc so their device
    // can detect them as a student on next login.
    if (studentUid.isNotEmpty) {
      await firestoreDb
          .collection('users')
          .doc(studentUid)
          .collection('enrollment')
          .doc(tutorId)
          .set({
        'tutorId': tutorId,
        'tutorName': (data['clientName'] as String?) ?? '',
        'status': 'enrolled',
        'joinRequestId': docId,
        'enrolledAt': FieldValue.serverTimestamp(),
      });
    }
  }
}
