abstract class ClientEvent {
  const ClientEvent();
}

class LoadClients extends ClientEvent {
  const LoadClients();
}

class SearchClients extends ClientEvent {
  final String query;
  final List<dynamic> sessions;
  SearchClients(this.query, {this.sessions = const []});
}

class AddNoteToClient extends ClientEvent {
  final String entityId;
  final String note;
  final DateTime? createdAt;

  AddNoteToClient({
    required this.entityId,
    required this.note,
    this.createdAt,
  });
}

class AddPaymentToClient extends ClientEvent {
  final String entityId;
  final double amount;
  final String? note;
  final DateTime? scheduledAt;

  AddPaymentToClient({
    required this.entityId,
    required this.amount,
    this.note,
    this.scheduledAt,
  });
}

class CreateClient extends ClientEvent {
  final String name;
  final String primaryContact;
  final String? firebaseUid;
  final String? referredBy;
  final String? middleName;
  final String? countryCode;
  final String? email;
  final String? gender;
  final DateTime? dateOfBirth;
  final String? address;

  CreateClient({
    required this.name,
    required this.primaryContact,
    this.firebaseUid,
    this.referredBy,
    this.middleName,
    this.countryCode,
    this.email,
    this.gender,
    this.dateOfBirth,
    this.address,
  });
}

class UpdateClientStatus extends ClientEvent {
  final String entityId;
  final String status;
  final DateTime? createdAt;
  final String? refId;

  UpdateClientStatus({
    required this.entityId,
    required this.status,
    this.createdAt,
    this.refId,
  });
}

class UpdateClientDetails extends ClientEvent {
  final String entityId;
  final String? name;
  final String? middleName;
  final String? primaryContact;
  final String? countryCode;
  final String? email;
  final String? gender;
  final DateTime? dateOfBirth;
  final String? address;
  final String? currency;
  final String? firebaseUid;

  UpdateClientDetails({
    required this.entityId,
    this.name,
    this.middleName,
    this.primaryContact,
    this.countryCode,
    this.email,
    this.gender,
    this.dateOfBirth,
    this.address,
    this.currency,
    this.firebaseUid,
  });
}

class ClearPaymentStatusForDate extends ClientEvent {
  final String entityId;
  final DateTime date;
  final String? paymentId;

  ClearPaymentStatusForDate({
    required this.entityId,
    required this.date,
    this.paymentId,
  });
}

class RescheduleClientPayment extends ClientEvent {
  final String entityId;
  final String paymentId;
  final DateTime oldDate;
  final DateTime newDate;

  RescheduleClientPayment({
    required this.entityId,
    required this.paymentId,
    required this.oldDate,
    required this.newDate,
  });
}

class MarkClientPaidFully extends ClientEvent {
  final String entityId;
  final DateTime fromDate;

  MarkClientPaidFully({
    required this.entityId,
    required this.fromDate,
  });
}

class RevertClientPaidFully extends ClientEvent {
  final String entityId;

  RevertClientPaidFully({required this.entityId});
}

class DeleteClient extends ClientEvent {
  final String entityId;
  DeleteClient({required this.entityId});
}

class RestoreClient extends ClientEvent {
  final String entityId;
  RestoreClient({required this.entityId});
}

class PermanentlyDeleteClient extends ClientEvent {
  final String entityId;
  PermanentlyDeleteClient({required this.entityId});
}