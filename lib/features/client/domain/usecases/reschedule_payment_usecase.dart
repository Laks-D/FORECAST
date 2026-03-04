import '../repositories/client_repository.dart';

class ReschedulePaymentUseCase {
  final ClientRepository repository;

  const ReschedulePaymentUseCase(this.repository);

  void execute({
    required String entityId,
    required String paymentId,
    required DateTime oldDate,
    required DateTime newDate,
  }) {
    repository.reschedulePayment(
      entityId: entityId,
      paymentId: paymentId,
      oldDate: oldDate,
      newDate: newDate,
    );
  }
}
