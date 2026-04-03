import '../repositories/client_repository.dart';

class AddClientStatusUseCase {
  final ClientRepository repository;

  const AddClientStatusUseCase(this.repository);

  void execute({
    required String entityId,
    required String status,
    DateTime? createdAt,
    String? refId,
  }) {
    repository.addStatusChange(
      entityId: entityId,
      status: status,
      createdAt: createdAt,
      refId: refId,
    );
  }
}
