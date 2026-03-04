import '../repositories/client_repository.dart';

class UpdateClientDetailsUseCase {
  final ClientRepository repository;

  const UpdateClientDetailsUseCase(this.repository);

  void execute({
    required String entityId,
    required String name,
    required String primaryContact,
    String? middleName,
    String? countryCode,
    String? email,
    String? gender,
    DateTime? dateOfBirth,
    String? address,
  }) {
    repository.updateClientDetails(
      entityId: entityId,
      name: name,
      primaryContact: primaryContact,
      middleName: middleName,
      countryCode: countryCode,
      email: email,
      gender: gender,
      dateOfBirth: dateOfBirth,
      address: address,
    );
  }
}
