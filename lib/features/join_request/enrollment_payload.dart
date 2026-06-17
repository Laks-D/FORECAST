/// Builds the field map for an enrollment document
/// (`users/{studentUid}/enrollment/{tutorId}`).
///
/// Phase 7 enrichment: adds `studentUid` and `source` alongside the existing
/// fields. The server timestamp (`enrolledAt`) is appended by the caller since
/// `FieldValue.serverTimestamp()` is not a plain value.
///
/// `status` keeps the existing 'enrolled' default so current readers are
/// unaffected; richer states (active/paused/ended) can layer on later.
Map<String, dynamic> buildEnrollmentPayload({
  required String tutorId,
  required String studentUid,
  String tutorName = '',
  String source = 'qr', // qr | manual | orphan_match
  String? joinRequestId,
  String status = 'enrolled',
}) {
  return {
    'tutorId': tutorId,
    'tutorName': tutorName,
    'studentUid': studentUid,
    'status': status,
    'source': source,
    if (joinRequestId != null) 'joinRequestId': joinRequestId,
  };
}
