import '../entities/client.dart';

abstract class ClientRepository {
  List<Client> getClients();

  void addNote({
    required String entityId,
    required String note,
    DateTime? createdAt,
  });

  void addPayment({
    required String entityId,
    required double amount,
    String? note,
    DateTime? scheduledAt,
  });

  void addStatusChange({
    required String entityId,
    required String status,
    DateTime? createdAt,
  });

  void clearPaymentStatusesForDate({
    required String entityId,
    required DateTime date,
  });

  void reschedulePayment({
    required String entityId,
    required String paymentId,
    required DateTime oldDate,
    required DateTime newDate,
  });

  void mergePayments({
    required String entityId,
    required String sourcePaymentId,
    required DateTime sourceDate,
    required String targetPaymentId,
    required DateTime targetDate,
    required double mergedAmount,
    String? mergedNote,
  });

  void markPaidFully({
    required String entityId,
    required DateTime fromDate,
  });

  void revertPaidFully({required String entityId});

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
  });

  void createClient({
    required String name,
    required String primaryContact,
    String? middleName,
    String? countryCode,
    String? email,
    String? gender,
    DateTime? dateOfBirth,
    String? address,
  });

  Future<void> persist();
  Future<void> loadFromStorage();
}