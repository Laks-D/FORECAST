import '../repositories/client_repository.dart';

class AddClientNoteUseCase {
  final ClientRepository repository;

  const AddClientNoteUseCase(this.repository);

  void execute({
    required String entityId,
    required String note,
    DateTime? createdAt,
  }) {
    repository.addNote(
      entityId: entityId,
      note: note,
      createdAt: createdAt,
    );
  }
}