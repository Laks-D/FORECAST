import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:snow/features/payment/data/firestore_payment_repository.dart';
import 'package:snow/features/payment/data/in_memory_payment_repository.dart';
import 'package:snow/features/payment/domain/entities/payment.dart';

Payment _p(
  String id,
  String clientId, {
  double amount = 100,
  PaymentStatus status = PaymentStatus.unpaid,
  DateTime? due,
}) =>
    Payment(
      paymentId: id,
      tutorId: 'tutor1',
      clientId: clientId,
      amount: amount,
      status: status,
      dueDate: due ?? DateTime(2026, 1, 1),
    );

void main() {
  group('Payment model', () {
    test('round-trips through json', () {
      final p = _p('p1', 'c1',
          amount: 250.5, status: PaymentStatus.willPayLater, due: DateTime(2026, 3, 9));
      final back = Payment.fromJson(p.toJson());
      expect(back.paymentId, 'p1');
      expect(back.clientId, 'c1');
      expect(back.amount, 250.5);
      expect(back.status, PaymentStatus.willPayLater);
      expect(back.dueDate, DateTime(2026, 3, 9));
    });

    test('status parser tolerates legacy strings', () {
      expect(PaymentStatus.fromName('Will pay later'), PaymentStatus.willPayLater);
      expect(PaymentStatus.fromName('Paid fully'), PaymentStatus.paid);
      expect(PaymentStatus.fromName('garbage'), PaymentStatus.unpaid);
      expect(PaymentStatus.fromName('paid'), PaymentStatus.paid);
    });
  });

  group('FirestorePaymentRepository (fake firestore)', () {
    late FakeFirebaseFirestore fake;
    late FirestorePaymentRepository repo;

    setUp(() {
      fake = FakeFirebaseFirestore();
      repo = FirestorePaymentRepository(
        firestore: fake,
        targetUid: () async => 'tutor1',
      );
    });

    test('add writes to users/{uid}/payments and reads back', () async {
      await repo.add(_p('p1', 'c1'));
      final doc =
          await fake.collection('users').doc('tutor1').collection('payments').doc('p1').get();
      expect(doc.exists, true);
      expect(doc.data()!['clientId'], 'c1');

      final got = await repo.getForClient('c1');
      expect(got.length, 1);
      expect(got.first.paymentId, 'p1');
    });

    test('getForClient filters by client', () async {
      await repo.add(_p('p1', 'c1'));
      await repo.add(_p('p2', 'c2'));
      await repo.add(_p('p3', 'c1'));
      expect((await repo.getForClient('c1')).length, 2);
      expect((await repo.getForClient('c2')).length, 1);
    });

    test('getAll is ordered by dueDate ascending', () async {
      await repo.add(_p('late', 'c1', due: DateTime(2026, 12, 1)));
      await repo.add(_p('early', 'c1', due: DateTime(2026, 1, 1)));
      final all = await repo.getAll();
      expect(all.map((e) => e.paymentId).toList(), ['early', 'late']);
    });

    test('markPaid flips status + records paidDate', () async {
      await repo.add(_p('p1', 'c1'));
      await repo.markPaid('p1', paidDate: DateTime(2026, 2, 2), method: 'cash');
      final got = (await repo.getForClient('c1')).first;
      expect(got.status, PaymentStatus.paid);
      expect(got.paidDate, DateTime(2026, 2, 2));
      expect(got.method, 'cash');
    });

    test('setStatus + delete work', () async {
      await repo.add(_p('p1', 'c1'));
      await repo.setStatus('p1', PaymentStatus.overdue);
      expect((await repo.getForClient('c1')).first.status, PaymentStatus.overdue);
      await repo.delete('p1');
      expect((await repo.getForClient('c1')).isEmpty, true);
    });

    test('null target uid yields empty, never throws', () async {
      final nullRepo =
          FirestorePaymentRepository(firestore: fake, targetUid: () async => null);
      await nullRepo.add(_p('p1', 'c1')); // no-op
      expect(await nullRepo.getAll(), isEmpty);
    });

    test('watchForClient streams updates', () async {
      final emissions = <int>[];
      final sub = repo.watchForClient('c1').listen((l) => emissions.add(l.length));
      await Future<void>.delayed(const Duration(milliseconds: 10));
      await repo.add(_p('p1', 'c1'));
      await Future<void>.delayed(const Duration(milliseconds: 10));
      await sub.cancel();
      expect(emissions.last, greaterThanOrEqualTo(1));
    });
  });

  group('InMemoryPaymentRepository parity', () {
    test('matches Firestore sort/filter semantics', () async {
      final repo = InMemoryPaymentRepository();
      await repo.add(_p('late', 'c1', due: DateTime(2026, 12, 1)));
      await repo.add(_p('early', 'c1', due: DateTime(2026, 1, 1)));
      await repo.add(_p('other', 'c2'));
      expect((await repo.getAll()).map((e) => e.paymentId).first, 'early');
      expect((await repo.getForClient('c1')).length, 2);
      await repo.markPaid('early');
      expect((await repo.getForClient('c1'))
          .firstWhere((p) => p.paymentId == 'early')
          .status, PaymentStatus.paid);
      repo.dispose();
    });
  });
}
