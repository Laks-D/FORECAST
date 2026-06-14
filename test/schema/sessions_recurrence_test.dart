import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:snow/features/calendar/data/recurrence_rule_repository.dart';
import 'package:snow/features/calendar/domain/entities/recurrence_rule.dart';
import 'package:snow/features/calendar/domain/entities/schedule_session.dart';

void main() {
  group('ScheduleSession enrichment (Phase 6)', () {
    test('new fields round-trip', () {
      final s = ScheduleSession(
        id: 1,
        clientId: 'c1',
        status: 'scheduled',
        sessionNo: 1,
        time: '10:00',
        date: '2026-06-01',
        duration: SessionDuration.twoHours,
        programId: 'prog_guitar',
        recurrenceId: 'rec_1',
      );
      final back = ScheduleSession.fromJson(s.toJson());
      expect(back.programId, 'prog_guitar');
      expect(back.recurrenceId, 'rec_1');
      expect(back.durationMins, 120);
    });

    test('legacy json without new fields still parses', () {
      final legacy = {
        'id': 2,
        'clientId': 'c1',
        'status': 'scheduled',
        'sessionNo': 1,
        'time': '09:00',
        'date': '2026-01-01',
      };
      final s = ScheduleSession.fromJson(legacy);
      expect(s.programId, isNull);
      expect(s.recurrenceId, isNull);
      expect(s.durationMins, isNull);
    });
  });

  group('FirestoreRecurrenceRuleRepository', () {
    late FakeFirebaseFirestore fake;
    late FirestoreRecurrenceRuleRepository repo;

    setUp(() {
      fake = FakeFirebaseFirestore();
      repo = FirestoreRecurrenceRuleRepository(
          firestore: fake, targetUid: () async => 'tutor1');
    });

    RecurrenceRule rule(String id) => RecurrenceRule(
          recurrenceId: id,
          tutorId: 'tutor1',
          clientId: 'c1',
          frequency: 'weekly',
          interval: 1,
          byWeekday: const [0, 2, 4],
          startDate: DateTime(2026, 6, 1),
          endDate: DateTime(2026, 9, 1),
          time: '17:30',
        );

    test('upsert + getById round-trips all fields', () async {
      await repo.upsert(rule('r1'));
      final got = await repo.getById('r1');
      expect(got, isNotNull);
      expect(got!.byWeekday, [0, 2, 4]);
      expect(got.frequency, 'weekly');
      expect(got.startDate, DateTime(2026, 6, 1));
      expect(got.endDate, DateTime(2026, 9, 1));
      expect(got.time, '17:30');

      final doc = await fake
          .collection('users')
          .doc('tutor1')
          .collection('recurrence_rules')
          .doc('r1')
          .get();
      expect(doc.exists, true);
    });

    test('getAll + delete + null uid no-op', () async {
      await repo.upsert(rule('r1'));
      await repo.upsert(rule('r2'));
      expect((await repo.getAll()).length, 2);
      await repo.delete('r1');
      expect((await repo.getAll()).length, 1);

      final nullRepo = FirestoreRecurrenceRuleRepository(
          firestore: fake, targetUid: () async => null);
      expect(await nullRepo.getAll(), isEmpty);
      expect(await nullRepo.getById('r2'), isNull);
    });
  });

  group('InMemoryRecurrenceRuleRepository parity', () {
    test('crud', () async {
      final r = InMemoryRecurrenceRuleRepository();
      await r.upsert(RecurrenceRule(
        recurrenceId: 'r1',
        tutorId: 't',
        clientId: 'c',
        frequency: 'daily',
        startDate: DateTime(2026, 1, 1),
        time: '08:00',
      ));
      expect((await r.getById('r1'))!.frequency, 'daily');
      await r.delete('r1');
      expect(await r.getById('r1'), isNull);
    });
  });
}
