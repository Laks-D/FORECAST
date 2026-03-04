import '../repositories/client_repository.dart';

class CreateClientUseCase {
  final ClientRepository repository;

  const CreateClientUseCase(this.repository);

  void execute({
    required String name,
    required String primaryContact,
    String? middleName,
    String? countryCode,
    String? email,
    String? gender,
    DateTime? dateOfBirth,
    String? address,
  }) {
    repository.createClient(
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