/// An immutable audit record, stored at `users/{actorUid}/audit_log/{logId}`.
///
/// Append-only (firestore.rules forbid update/delete). Captures who did what to
/// which entity, with optional before/after snapshots for dispute resolution.
class AuditEntry {
  const AuditEntry({
    required this.logId,
    required this.actorUid,
    required this.action,
    required this.entity,
    required this.entityId,
    this.before,
    this.after,
    this.at,
  });

  final String logId;
  final String actorUid;
  final String action; // create | update | delete | login | payment | ...
  final String entity; // client | session | payment | program | enrollment
  final String entityId;
  final Map<String, dynamic>? before;
  final Map<String, dynamic>? after;
  final DateTime? at;

  Map<String, dynamic> toJson() => {
        'logId': logId,
        'actorUid': actorUid,
        'action': action,
        'entity': entity,
        'entityId': entityId,
        if (before != null) 'before': before,
        if (after != null) 'after': after,
        if (at != null) 'at': at!.toIso8601String(),
      };

  static DateTime? _date(dynamic v) {
    if (v is String) return DateTime.tryParse(v);
    try {
      final dt = (v as dynamic).toDate();
      if (dt is DateTime) return dt;
    } catch (_) {}
    return null;
  }

  factory AuditEntry.fromJson(Map<String, dynamic> json, {String? id}) {
    return AuditEntry(
      logId: (json['logId'] as String?) ?? id ?? '',
      actorUid: (json['actorUid'] as String?) ?? '',
      action: (json['action'] as String?) ?? '',
      entity: (json['entity'] as String?) ?? '',
      entityId: (json['entityId'] as String?) ?? '',
      before: json['before'] is Map
          ? Map<String, dynamic>.from(json['before'] as Map)
          : null,
      after: json['after'] is Map
          ? Map<String, dynamic>.from(json['after'] as Map)
          : null,
      at: _date(json['at']),
    );
  }
}
