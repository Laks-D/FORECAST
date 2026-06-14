import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:snow/features/audit/audit_entry.dart';
import 'package:snow/features/audit/audit_log_repository.dart';

AuditEntry _a(String id, {String action = 'create', String entity = 'client'}) =>
    AuditEntry(
      logId: id,
      actorUid: 'u1',
      action: action,
      entity: entity,
      entityId: 'e_$id',
      after: {'k': 'v'},
      at: DateTime(2026, 1, 1),
    );

void main() {
  group('AuditEntry model', () {
    test('json round-trip preserves before/after maps', () {
      final e = AuditEntry(
        logId: 'l1',
        actorUid: 'u1',
        action: 'update',
        entity: 'payment',
        entityId: 'p1',
        before: {'status': 'unpaid'},
        after: {'status': 'paid'},
        at: DateTime(2026, 5, 5),
      );
      final back = AuditEntry.fromJson(e.toJson());
      expect(back.action, 'update');
      expect(back.before!['status'], 'unpaid');
      expect(back.after!['status'], 'paid');
    });
  });

  group('FirestoreAuditLogRepository', () {
    late FakeFirebaseFirestore fake;
    late FirestoreAuditLogRepository repo;

    setUp(() {
      fake = FakeFirebaseFirestore();
      repo = FirestoreAuditLogRepository(
          firestore: fake, actorUid: () async => 'u1');
    });

    test('append writes under users/{uid}/audit_log', () async {
      await repo.append(_a('1'));
      await repo.append(_a('2', action: 'delete'));
      final snap =
          await fake.collection('users').doc('u1').collection('audit_log').get();
      expect(snap.docs.length, 2);
      final recent = await repo.getRecent();
      expect(recent.length, 2);
    });

    test('null actor uid is a safe no-op', () async {
      final r = FirestoreAuditLogRepository(
          firestore: fake, actorUid: () async => null);
      await r.append(_a('x'));
      expect(await r.getRecent(), isEmpty);
    });
  });

  group('InMemoryAuditLogRepository parity', () {
    test('append + getRecent newest-first', () async {
      final r = InMemoryAuditLogRepository();
      await r.append(_a('1'));
      await r.append(_a('2'));
      final recent = await r.getRecent();
      expect(recent.first.logId, '2');
    });
  });
}
