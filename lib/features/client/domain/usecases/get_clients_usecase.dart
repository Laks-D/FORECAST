import '../entities/client.dart';
import '../repositories/client_repository.dart';

class GetClientsUseCase {
  final ClientRepository repository;

  const GetClientsUseCase(this.repository);

  List<Client> execute() {
    return repository.getClients();
  }
}