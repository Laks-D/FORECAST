import 'package:cloud_firestore/cloud_firestore.dart';

/// Represents a client-to-admin join request stored in the `join_requests`
/// Firestore top-level collection.
class JoinRequestModel {
  const JoinRequestModel({
    required this.id,
    required this.tutorId,
    required this.clientFirebaseUid,
    required this.clientName,
    required this.clientPhone,
    required this.clientEmail,
    required this.status,
    required this.createdAt,
  });

  final String id;
  final String tutorId;
  final String clientFirebaseUid;
  final String clientName;
  final String clientPhone;
  final String clientEmail;

  /// `pending` | `accepted` | `rejected`
  final String status;
  final DateTime createdAt;

  factory JoinRequestModel.fromFirestore(
    String id,
    Map<String, dynamic> data,
  ) {
    return JoinRequestModel(
      id: id,
      tutorId: (data['tutorId'] as String?) ?? '',
      clientFirebaseUid: (data['clientFirebaseUid'] as String?) ?? '',
      clientName: (data['clientName'] as String?) ?? 'Unknown',
      clientPhone: (data['clientPhone'] as String?) ?? '',
      clientEmail: (data['clientEmail'] as String?) ?? '',
      status: (data['status'] as String?) ?? 'pending',
      createdAt: (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }

  Map<String, dynamic> toMap() => {
        'tutorId': tutorId,
        'clientFirebaseUid': clientFirebaseUid,
        'clientName': clientName,
        'clientPhone': clientPhone,
        'clientEmail': clientEmail,
        'status': status,
        'createdAt': FieldValue.serverTimestamp(),
      };
}
