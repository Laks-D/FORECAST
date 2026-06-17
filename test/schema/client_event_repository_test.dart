import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:snow/features/client/data/client_event_repository.dart';
import 'package:snow/features/client/domain/entities/client_event.dart';

ClientEvent _e(
  String id,
  String clientId, {
  ClientEventType type = ClientEventType.note,
  DateTime? at,
  String? note,
  String? status,
}) =>
    ClientEvent(
      eventId: id,
      clientId: clientId,
      tutorId: 'tutor1',
      type: type,
      note: note,
      status: status,
      createdAt: at ?? DateTime(2026, 1, 1),
    );

void main() {
  group('ClientEvent model', () {
    test('json round-trip + type tolerance', () {
      final e = _e('e1', 'c1',
          type: ClientEventType.statusChanged, status: 'Active', at: DateTime(2026, 5, 5));
      final back = ClientEvent.fromJson(e.toJson());
      expect(back.type, ClientEventType.statusChanged);
      expect(back.status, 'Active');
      expect(ClientEventType.fromName('Profile created'),
          ClientEventType.profileCreated);
      expect(ClientEventType.fromName('note'), ClientEventType.note);
    });
  });

  group('FirestoreClientEventRepository', () {
    late FakeFirebaseFirestore fake;
    late FirestoreClientEventRepository repo;

    setUp(() {
      fake = FakeFirebaseFirestore();
      repo = FirestoreClientEventRepository(
          firestore: fake, targetUid: () async => 'tutor1');
    });

    test('add writes under users/{uid}/client_events + filters by client', () async {
      await repo.add(_e('e1', 'c1', note: 'hi'));
      await repo.add(_e('e2', 'c2'));
      final doc = await fake
          .collection('users')
          .doc('tutor1')
          .collection('client_events')
          .doc('e1')
          .get();
      expect(doc.exists, true);
      expect((await repo.getForClient('c1')).length, 1);
      expect((await repo.getForClient('c1')).first.note, 'hi');
    });

    test('getForClient sorts oldest-first (chronological timeline)', () async {
      await repo.add(_e('new', 'c1', at: DateTime(2026, 9, 1)));
      await repo.add(_e('old', 'c1', at: DateTime(2026, 1, 1)));
      expect((await repo.getForClient('c1')).map((e) => e.eventId).toList(),
          ['old', 'new']);
    });

    test('getForStudent filters by firebaseUid (rule-correct student read)', () async {
      await repo.add(ClientEvent(
          eventId: 'e1',
          clientId: 'c1',
          tutorId: 'tutor1',
          firebaseUid: 'studentA',
          type: ClientEventType.note,
          note: 'mine',
          createdAt: DateTime(2026, 1, 1)));
      await repo.add(ClientEvent(
          eventId: 'e2',
          clientId: 'c2',
          tutorId: 'tutor1',
          firebaseUid: 'studentB',
          type: ClientEventType.note,
          createdAt: DateTime(2026, 1, 1)));
      final mine = await repo.getForStudent('studentA');
      expect(mine.length, 1);
      expect(mine.first.eventId, 'e1');
    });

    test('delete + null uid no-op', () async {
      await repo.add(_e('e1', 'c1'));
      await repo.delete('e1');
      expect(await repo.getForClient('c1'), isEmpty);

      final nullRepo =
          FirestoreClientEventRepository(firestore: fake, targetUid: () async => null);
      await nullRepo.add(_e('x', 'c1'));
      expect(await nullRepo.getForClient('c1'), isEmpty);
    });
  });

  group('InMemoryClientEventRepository parity', () {
    test('add + filter + sort', () async {
      final r = InMemoryClientEventRepository();
      await r.add(_e('a', 'c1', at: DateTime(2026, 3, 1)));
      await r.add(_e('b', 'c1', at: DateTime(2026, 1, 1)));
      await r.add(_e('c', 'c2'));
      expect((await r.getForClient('c1')).first.eventId, 'b');
      expect((await r.getForClient('c2')).length, 1);
    });
  });
}
