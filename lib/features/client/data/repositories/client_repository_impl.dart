import '../../domain/entities/client.dart';
import '../../domain/repositories/client_repository.dart';
import '../datasources/client_local_datasource.dart';

class ClientRepositoryImpl implements ClientRepository {
  final ClientLocalDataSource localDataSource;

  const ClientRepositoryImpl(this.localDataSource);

  @override
  List<Client> getClients() {
    return localDataSource.fetchClients();
  }

  @override
  void addNote({
    required String entityId,
    required String note,
    DateTime? createdAt,
  }) {
    localDataSource.addNote(entityId, note, createdAt: createdAt);
  }

  @override
  void addPayment({
    required String entityId,
    required double amount,
    String? note,
    DateTime? scheduledAt,
  }) {
    localDataSource.addPayment(
      entityId: entityId,
      amount: amount,
      note: note,
      scheduledAt: scheduledAt,
    );
  }

  @override
  void addStatusChange({
    required String entityId,
    required String status,
    DateTime? createdAt,
  }) {
    localDataSource.addStatusChange(
      entityId: entityId,
      status: status,
      createdAt: createdAt,
    );
  }

  @override
  void clearPaymentStatusesForDate({
    required String entityId,
    required DateTime date,
  }) {
    localDataSource.clearPaymentStatusesForDate(
      entityId: entityId,
      date: date,
    );
  }

  @override
  void reschedulePayment({
    required String entityId,
    required String paymentId,
    required DateTime oldDate,
    required DateTime newDate,
  }) {
    localDataSource.reschedulePayment(
      entityId: entityId,
      paymentId: paymentId,
      oldDate: oldDate,
      newDate: newDate,
    );
  }

  @override
  void mergePayments({
    required String entityId,
    required String sourcePaymentId,
    required DateTime sourceDate,
    required String targetPaymentId,
    required DateTime targetDate,
    required double mergedAmount,
    String? mergedNote,
  }) {
    localDataSource.mergePayments(
      entityId: entityId,
      sourcePaymentId: sourcePaymentId,
      sourceDate: sourceDate,
      targetPaymentId: targetPaymentId,
      targetDate: targetDate,
      mergedAmount: mergedAmount,
      mergedNote: mergedNote,
    );
  }

  @override
  void markPaidFully({
    required String entityId,
    required DateTime fromDate,
  }) {
    localDataSource.markPaidFully(
      entityId: entityId,
      fromDate: fromDate,
    );
  }

  @override
  void revertPaidFully({required String entityId}) {
    localDataSource.revertPaidFully(entityId: entityId);
  }

  @override
  void updateClientDetails({
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
    localDataSource.updateClientDetails(
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

  @override
  void createClient({
    required String name,
    required String primaryContact,
    String? middleName,
    String? countryCode,
    String? email,
    String? gender,
    DateTime? dateOfBirth,
    String? address,
  }) {
    localDataSource.addClient(
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

  @override
  Future<void> persist() => localDataSource.persist();

  @override
  Future<void> loadFromStorage() => localDataSource.loadFromStorage();
}