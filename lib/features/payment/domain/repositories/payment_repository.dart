import '../entities/payment.dart';

/// Abstraction over the `payments` sub-collection.
///
/// Two implementations:
///  - [FirestorePaymentRepository] (production, talks to Cloud Firestore)
///  - InMemoryPaymentRepository (tests / offline fake)
abstract class PaymentRepository {
  /// All payments for one student (by tutor-facing clientId), newest first.
  /// TUTOR-side read: the `clientId` filter is allowed only for the owner.
  Future<List<Payment>> getForClient(String clientId);

  /// Live stream of one student's payments (tutor-side).
  Stream<List<Payment>> watchForClient(String clientId);

  /// STUDENT-side read. Must filter by `firebaseUid` (not clientId): the
  /// Firestore rule scopes an enrolled student's read by the denormalized
  /// `firebaseUid` field, and list-query rules are evaluated against the query
  /// constraints — a clientId filter would be denied.
  Future<List<Payment>> getForStudent(String firebaseUid);

  /// Live stream of the signed-in student's own payments.
  Stream<List<Payment>> watchForStudent(String firebaseUid);

  /// Every payment for the current tutor (used by the payments queue),
  /// ordered by dueDate ascending.
  Future<List<Payment>> getAll();

  /// Live stream of every payment for the current tutor.
  Stream<List<Payment>> watchAll();

  Future<void> add(Payment payment);

  Future<void> update(Payment payment);

  Future<void> delete(String paymentId);

  /// Convenience: flip a payment to paid (optionally record method/date).
  Future<void> markPaid(String paymentId, {DateTime? paidDate, String? method});

  /// Convenience: set an arbitrary status.
  Future<void> setStatus(String paymentId, PaymentStatus status);
}
