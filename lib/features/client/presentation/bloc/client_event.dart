abstract class ClientEvent {}

class LoadClients extends ClientEvent {}

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
  final String? middleName;
  final String? countryCode;
  final String? email;
  final String? gender;
  final DateTime? dateOfBirth;
  final String? address;

  CreateClient({
    required this.name,
    required this.primaryContact,
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

  UpdateClientStatus({
    required this.entityId,
    required this.status,
    this.createdAt,
  });
}

class UpdateClientDetails extends ClientEvent {
  final String entityId;
  final String name;
  final String primaryContact;
  final String? middleName;
  final String? countryCode;
  final String? email;
  final String? gender;
  final DateTime? dateOfBirth;
  final String? address;

  UpdateClientDetails({
    required this.entityId,
    required this.name,
    required this.primaryContact,
    this.middleName,
    this.countryCode,
    this.email,
    this.gender,
    this.dateOfBirth,
    this.address,
  });
}

class ClearPaymentStatusForDate extends ClientEvent {
  final String entityId;
  final DateTime date;

  ClearPaymentStatusForDate({
    required this.entityId,
    required this.date,
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

class MergeClientPayments extends ClientEvent {
  final String entityId;
  final String sourcePaymentId;
  final DateTime sourceDate;
  final String targetPaymentId;
  final DateTime targetDate;
  final double mergedAmount;
  final String? mergedNote;

  MergeClientPayments({
    required this.entityId,
    required this.sourcePaymentId,
    required this.sourceDate,
    required this.targetPaymentId,
    required this.targetDate,
    required this.mergedAmount,
    this.mergedNote,
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