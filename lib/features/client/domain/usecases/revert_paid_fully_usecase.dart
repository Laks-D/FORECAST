import '../repositories/client_repository.dart';

class RevertPaidFullyUseCase {
  final ClientRepository repository;

  const RevertPaidFullyUseCase(this.repository);

  void execute({required String entityId}) {
    repository.revertPaidFully(entityId: entityId);
  }
}
