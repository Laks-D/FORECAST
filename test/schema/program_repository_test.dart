import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:snow/features/course/data/program_repository.dart';
import 'package:snow/features/course/domain/entities/program.dart';

Program _p(String name) =>
    Program(programId: Program.slug(name), tutorId: 'tutor1', name: name);

void main() {
  group('Program model', () {
    test('slug normalizes, json round-trips', () {
      expect(Program.slug('Guitar - Beginner!'), 'guitar_beginner');
      expect(Program.slug('   '), 'program');
      final p = Program(
          programId: 'x',
          tutorId: 't',
          name: 'Piano',
          numberOfClasses: 12,
          classDuration: '45 min');
      final back = Program.fromJson(p.toJson());
      expect(back.name, 'Piano');
      expect(back.numberOfClasses, 12);
      expect(back.classDuration, '45 min');
    });
  });

  group('FirestoreProgramRepository', () {
    late FakeFirebaseFirestore fake;
    late FirestoreProgramRepository repo;

    setUp(() {
      fake = FakeFirebaseFirestore();
      repo = FirestoreProgramRepository(
          firestore: fake, targetUid: () async => 'tutor1');
    });

    test('upsert writes under users/{uid}/programs, sorted by name', () async {
      await repo.upsert(_p('Zebra'));
      await repo.upsert(_p('Apple'));
      final all = await repo.getAll();
      expect(all.map((e) => e.name).toList(), ['Apple', 'Zebra']);
      final doc = await fake
          .collection('users')
          .doc('tutor1')
          .collection('programs')
          .doc(Program.slug('Apple'))
          .get();
      expect(doc.exists, true);
    });

    test('replaceAll upserts new + deletes missing', () async {
      await repo.replaceAll([_p('A'), _p('B'), _p('C')]);
      expect((await repo.getAll()).length, 3);
      // Second save drops B and C, keeps A, adds D.
      await repo.replaceAll([_p('A'), _p('D')]);
      final names = (await repo.getAll()).map((e) => e.name).toList();
      expect(names, ['A', 'D']);
    });

    test('delete + null uid no-op', () async {
      await repo.upsert(_p('A'));
      await repo.delete(Program.slug('A'));
      expect(await repo.getAll(), isEmpty);

      final nullRepo =
          FirestoreProgramRepository(firestore: fake, targetUid: () async => null);
      await nullRepo.upsert(_p('Z'));
      expect(await nullRepo.getAll(), isEmpty);
    });
  });

  group('InMemoryProgramRepository parity', () {
    test('replaceAll semantics match', () async {
      final r = InMemoryProgramRepository();
      await r.replaceAll([_p('A'), _p('B')]);
      await r.replaceAll([_p('B'), _p('C')]);
      expect((await r.getAll()).map((e) => e.name).toList(), ['B', 'C']);
    });
  });
}
