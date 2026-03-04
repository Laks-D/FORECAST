import '../repositories/client_repository.dart';

class MarkPaidFullyUseCase {
  final ClientRepository repository;

  const MarkPaidFullyUseCase(this.repository);

  void execute({
    required String entityId,
    required DateTime fromDate,
  }) {
    repository.markPaidFully(
      entityId: entityId,
      fromDate: fromDate,
    );
  }
}
