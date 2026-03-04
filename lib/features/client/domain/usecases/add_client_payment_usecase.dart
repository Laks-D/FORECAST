import '../repositories/client_repository.dart';

class AddClientPaymentUseCase {
  final ClientRepository repository;

  const AddClientPaymentUseCase(this.repository);

  void execute({
    required String entityId,
    required double amount,
    String? note,
    DateTime? scheduledAt,
  }) {
    repository.addPayment(
      entityId: entityId,
      amount: amount,
      note: note,
      scheduledAt: scheduledAt,
    );
  }
}
