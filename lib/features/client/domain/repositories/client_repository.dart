import '../entities/client.dart';

abstract class ClientRepository {
  List<Client> getClients();

  /// Soft-deleted clients kept for restore.
  List<Client> getDeletedClients();

  /// Soft delete (move to deleted bucket).
  void deleteClient({required String entityId});

  /// Restore from deleted bucket.
  void restoreClient({required String entityId});

  /// Hard-delete immediately from the deleted bucket. Cannot be undone.
  Future<void> permanentlyDeleteClient({required String entityId});

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
    String? refId,
  });

  void clearPaymentStatusesForDate({
    required String entityId,
    required DateTime date,
    String? paymentId,
  });

  void reschedulePayment({
    required String entityId,
    required String paymentId,
    required DateTime oldDate,
    required DateTime newDate,
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
    String? firebaseUid,
    String? middleName,
    String? countryCode,
    String? email,
    String? gender,
    DateTime? dateOfBirth,
    String? address,
    String? currency,
  });

  void updateClientStatus({required String entityId, required String status});

  void createClient({
    required String name,
    required String primaryContact,
    String? firebaseUid,
    String? referredBy,
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