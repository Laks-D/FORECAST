import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';

import 'audit_entry.dart';
import 'audit_log_repository.dart';

/// Fire-and-forget audit logging. Every call is fully guarded and never
/// awaited in a user-action path, so a logging failure can never affect UX.
class AuditService {
  AuditService._();
  static final AuditService instance = AuditService._();

  AuditLogRepository _repo = FirestoreAuditLogRepository();

  /// Test seam.
  // ignore: avoid_setters_without_getters
  set repositoryForTest(AuditLogRepository r) => _repo = r;

  static int _seq = 0;

  void log({
    required String action,
    required String entity,
    required String entityId,
    Map<String, dynamic>? before,
    Map<String, dynamic>? after,
  }) {
    try {
      final uid = FirebaseAuth.instance.currentUser?.uid;
      if (uid == null || uid.isEmpty) return;
      _seq++;
      final logId = '${DateTime.now().millisecondsSinceEpoch}_$_seq';
      unawaited(_repo.append(AuditEntry(
        logId: logId,
        actorUid: uid,
        action: action,
        entity: entity,
        entityId: entityId,
        before: before,
        after: after,
        at: DateTime.now(),
      )));
    } catch (_) {
      // Never propagate.
    }
  }
}
