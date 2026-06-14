import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:snow/core/services/notification_storage.dart';
import 'package:snow/features/notifications/data/notification_record_repository.dart';

AppNotification _n(String id, {DateTime? at, bool read = false}) => AppNotification(
      id: id,
      title: 'T$id',
      body: 'B$id',
      type: AppNotificationType.general,
      createdAt: at ?? DateTime(2026, 1, 1),
      read: read,
    );

void main() {
  group('FirestoreNotificationRecordRepository', () {
    late FakeFirebaseFirestore fake;
    late FirestoreNotificationRecordRepository repo;

    setUp(() {
      fake = FakeFirebaseFirestore();
      repo = FirestoreNotificationRecordRepository(
        firestore: fake,
        uid: () async => 'u1',
      );
    });

    test('upsertAll writes docs under users/{uid}/notifications', () async {
      await repo.upsertAll([_n('a'), _n('b')]);
      final snap =
          await fake.collection('users').doc('u1').collection('notifications').get();
      expect(snap.docs.length, 2);
      expect((await repo.getAll()).length, 2);
    });

    test('getAll sorts newest first', () async {
      await repo.upsertAll([
        _n('old', at: DateTime(2026, 1, 1)),
        _n('new', at: DateTime(2026, 6, 1)),
      ]);
      expect((await repo.getAll()).first.id, 'new');
    });

    test('markRead + delete', () async {
      await repo.upsert(_n('a'));
      await repo.markRead('a');
      expect((await repo.getAll()).first.read, true);
      await repo.delete('a');
      expect(await repo.getAll(), isEmpty);
    });

    test('upsert is idempotent by id', () async {
      await repo.upsert(_n('a'));
      await repo.upsert(_n('a'));
      expect((await repo.getAll()).length, 1);
    });

    test('null uid is a safe no-op', () async {
      final r = FirestoreNotificationRecordRepository(
          firestore: fake, uid: () async => null);
      await r.upsertAll([_n('a')]);
      expect(await r.getAll(), isEmpty);
    });
  });

  group('InMemoryNotificationRecordRepository parity', () {
    test('upsert + read + markRead', () async {
      final r = InMemoryNotificationRecordRepository();
      await r.upsertAll([_n('a'), _n('b', at: DateTime(2026, 9, 1))]);
      expect((await r.getAll()).first.id, 'b');
      await r.markRead('a');
      expect((await r.getAll()).firstWhere((e) => e.id == 'a').read, true);
    });
  });
}
