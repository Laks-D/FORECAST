import 'dart:async';

import '../domain/entities/payment.dart';
import '../domain/repositories/payment_repository.dart';

/// In-memory [PaymentRepository] for tests and offline fakes.
///
/// Mirrors the Firestore implementation's sort/filter semantics so that
/// use-case and BLoC tests can run with zero Firebase dependency.
class InMemoryPaymentRepository implements PaymentRepository {
  final Map<String, Payment> _store = {};
  final _controller = StreamController<void>.broadcast();

  List<Payment> get all => _store.values.toList(growable: false);

  void _emit() => _controller.add(null);

  @override
  Future<List<Payment>> getForClient(String clientId) async {
    final list = _store.values.where((p) => p.clientId == clientId).toList();
    list.sort((a, b) => b.dueDate.compareTo(a.dueDate));
    return list;
  }

  @override
  Stream<List<Payment>> watchForClient(String clientId) async* {
    yield await getForClient(clientId);
    yield* _controller.stream.asyncMap((_) => getForClient(clientId));
  }

  @override
  Future<List<Payment>> getForStudent(String firebaseUid) async {
    final list =
        _store.values.where((p) => p.firebaseUid == firebaseUid).toList();
    list.sort((a, b) => b.dueDate.compareTo(a.dueDate));
    return list;
  }

  @override
  Stream<List<Payment>> watchForStudent(String firebaseUid) async* {
    yield await getForStudent(firebaseUid);
    yield* _controller.stream.asyncMap((_) => getForStudent(firebaseUid));
  }

  @override
  Future<List<Payment>> getAll() async {
    final list = _store.values.toList();
    list.sort((a, b) => a.dueDate.compareTo(b.dueDate));
    return list;
  }

  @override
  Stream<List<Payment>> watchAll() async* {
    yield await getAll();
    yield* _controller.stream.asyncMap((_) => getAll());
  }

  @override
  Future<void> add(Payment payment) async {
    _store[payment.paymentId] = payment;
    _emit();
  }

  @override
  Future<void> update(Payment payment) async {
    _store[payment.paymentId] = payment;
    _emit();
  }

  @override
  Future<void> delete(String paymentId) async {
    _store.remove(paymentId);
    _emit();
  }

  @override
  Future<void> markPaid(String paymentId,
      {DateTime? paidDate, String? method}) async {
    final p = _store[paymentId];
    if (p == null) return;
    _store[paymentId] = p.copyWith(
      status: PaymentStatus.paid,
      paidDate: paidDate ?? DateTime.now(),
      method: method,
    );
    _emit();
  }

  @override
  Future<void> setStatus(String paymentId, PaymentStatus status) async {
    final p = _store[paymentId];
    if (p == null) return;
    _store[paymentId] = p.copyWith(status: status);
    _emit();
  }

  void dispose() => _controller.close();
}
