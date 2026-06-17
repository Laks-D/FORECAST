import '../entities/client.dart';

abstract class ClientRepository {
  Stream<List<Client>> watchClients();
  Future<List<Client>> getClients();
  Future<List<Client>> getDeletedClients();

  Future<void> addClient(Client client);
  Future<void> updateClient(Client client);

  Future<void> deleteClient({required String entityId});
  Future<void> restoreClient({required String entityId});
  Future<void> permanentlyDeleteClient({required String entityId});

  Future<void> loadFromStorage();
  Future<void> persist();
}