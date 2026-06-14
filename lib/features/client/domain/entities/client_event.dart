/// Kind of non-payment client timeline event.
enum ClientEventType {
  profileCreated,
  statusChanged,
  note;

  static ClientEventType fromName(String? raw) {
    final s = (raw ?? '').trim().toLowerCase();
    for (final v in ClientEventType.values) {
      if (v.name.toLowerCase() == s) return v;
    }
    if (s == 'profile created') return ClientEventType.profileCreated;
    if (s == 'status changed' || s == 'statuschange') {
      return ClientEventType.statusChanged;
    }
    return ClientEventType.note;
  }
}

/// A first-class client event (note / status change / profile-created), stored
/// at `users/{tutorUid}/client_events/{eventId}`.
///
/// Replaces the non-payment entries of the legacy client `timeline[]` array.
/// Payments live in the separate `payments` collection.
class ClientEvent {
  const ClientEvent({
    required this.eventId,
    required this.clientId,
    required this.tutorId,
    this.firebaseUid,
    required this.type,
    this.note,
    this.status,
    required this.createdAt,
  });

  final String eventId;
  final String clientId;
  final String tutorId;

  /// Denormalized student uid for scoped student reads (mirrors clients rule).
  final String? firebaseUid;
  final ClientEventType type;
  final String? note;
  final String? status;
  final DateTime createdAt;

  static String _iso(DateTime d) => d.toIso8601String();

  Map<String, dynamic> toJson() => {
        'eventId': eventId,
        'clientId': clientId,
        'tutorId': tutorId,
        if (firebaseUid != null) 'firebaseUid': firebaseUid,
        'type': type.name,
        if (note != null) 'note': note,
        if (status != null) 'status': status,
        'createdAt': _iso(createdAt),
      };

  static DateTime _parseDate(dynamic v) {
    if (v is String) return DateTime.tryParse(v) ?? DateTime(1970);
    try {
      final dt = (v as dynamic).toDate();
      if (dt is DateTime) return dt;
    } catch (_) {}
    return DateTime(1970);
  }

  factory ClientEvent.fromJson(Map<String, dynamic> json, {String? id}) {
    return ClientEvent(
      eventId: (json['eventId'] as String?) ?? id ?? '',
      clientId: (json['clientId'] as String?) ?? '',
      tutorId: (json['tutorId'] as String?) ?? '',
      firebaseUid: json['firebaseUid'] as String?,
      type: ClientEventType.fromName(json['type'] as String?),
      note: json['note'] as String?,
      status: json['status'] as String?,
      createdAt: _parseDate(json['createdAt']),
    );
  }
}
