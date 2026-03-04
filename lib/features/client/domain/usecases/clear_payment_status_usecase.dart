import '../repositories/client_repository.dart';

class ClearPaymentStatusUseCase {
  final ClientRepository repository;

  const ClearPaymentStatusUseCase(this.repository);

  void execute({
    required String entityId,
    required DateTime date,
  }) {
    repository.clearPaymentStatusesForDate(
      entityId: entityId,
      date: date,
    );
  }
}
