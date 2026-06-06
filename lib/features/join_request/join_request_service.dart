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
    required String clientEmail,
  }) async {
    final ref = firestoreDb.collection(_kCollection).doc();
    await ref.set({
      'tutorId': tutorId,
      'clientFirebaseUid': clientFirebaseUid,
      'clientName': clientName,
      'clientPhone': clientPhone,
      'clientEmail': clientEmail,
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
  ///
  /// On acceptance this also writes the enrollment record into the student's
  /// own sub-collection so their device knows they are enrolled.
  /// The tutor's client record in `users/{tutorId}/clients` is created by the
  /// UI layer (JoinRequestBanner → ClientBloc) because the Client entity
  /// requires richer local-state management.
  static Future<void> resolve(String docId, String status) async {
    assert(status == 'accepted' || status == 'rejected');

    // Fetch the request data first so we can use it even after the update.
    final reqSnap = await firestoreDb.collection(_kCollection).doc(docId).get();
    final data = reqSnap.data();

    await firestoreDb.collection(_kCollection).doc(docId).update({
      'status': status,
      'resolvedAt': FieldValue.serverTimestamp(),
    });

    if (status != 'accepted' || data == null) return;

    final tutorId = (data['tutorId'] as String?) ?? '';
    final studentUid = (data['clientFirebaseUid'] as String?) ?? '';
    if (tutorId.isEmpty || studentUid.isEmpty) return;

    // Resolve the tutor's display name from their profile doc.
    String tutorName = '';
    try {
      final tutorDoc = await firestoreDb.collection('users').doc(tutorId).get();
      tutorName = (tutorDoc.data()?['displayName'] as String?) ?? '';
    } catch (_) {
      // Non-fatal — tutorName stays empty rather than blocking enrollment.
    }

    // Write enrollment record to the client's own user doc so their device
    // can detect them as a client on next login / app restart.
    await firestoreDb
        .collection('users')
        .doc(studentUid)
        .collection('enrollment')
        .doc(tutorId)
        .set({
      'tutorId': tutorId,
      'tutorName': tutorName,
      'status': 'enrolled',
      'joinRequestId': docId,
      'enrolledAt': FieldValue.serverTimestamp(),
    });
  }

  /// Client-side: marks a pending request as `expired` when the waiting-page
  /// timeout fires.  This prevents stale `pending` docs from accumulating.
  static Future<void> markExpired(String docId) async {
    try {
      await firestoreDb.collection(_kCollection).doc(docId).update({
        'status': 'expired',
        'resolvedAt': FieldValue.serverTimestamp(),
      });
    } catch (_) {
      // Best-effort — the document may already be resolved.
    }
  }
}
