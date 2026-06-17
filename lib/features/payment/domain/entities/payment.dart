/// Payment status lifecycle for a single charge.
enum PaymentStatus {
  paid,
  unpaid,
  partial,
  willPayLater,
  overdue;

  static PaymentStatus fromName(String? raw) {
    final s = (raw ?? '').trim();
    for (final v in PaymentStatus.values) {
      if (v.name.toLowerCase() == s.toLowerCase()) return v;
    }
    // Legacy string tolerance.
    switch (s.toLowerCase()) {
      case 'will pay later':
        return PaymentStatus.willPayLater;
      case 'paid fully':
        return PaymentStatus.paid;
      default:
        return PaymentStatus.unpaid;
    }
  }
}

/// A first-class payment record, stored at
/// `users/{tutorUid}/payments/{paymentId}`.
///
/// Replaces the legacy approach of embedding payments as `timeline[]` entries
/// inside the client document. Dates are persisted as `yyyy-MM-dd` strings to
/// match the existing session/date conventions in this codebase.
class Payment {
  const Payment({
    required this.paymentId,
    required this.tutorId,
    required this.clientId,
    this.firebaseUid,
    this.sessionId,
    required this.amount,
    this.currency,
    required this.status,
    required this.dueDate,
    this.paidDate,
    this.method,
    this.note,
    this.createdAt,
    this.updatedAt,
  });

  final String paymentId;
  final String tutorId;
  final String clientId;

  /// Denormalized Firebase UID of the linked student (null until linked).
  /// Lets Firestore rules scope a student's read to their own payments only.
  final String? firebaseUid;
  final String? sessionId;
  final double amount;
  final String? currency;
  final PaymentStatus status;
  final DateTime dueDate;
  final DateTime? paidDate;
  final String? method;
  final String? note;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  bool get isSettled =>
      status == PaymentStatus.paid || status == PaymentStatus.partial;

  Payment copyWith({
    String? firebaseUid,
    String? sessionId,
    double? amount,
    String? currency,
    PaymentStatus? status,
    DateTime? dueDate,
    DateTime? paidDate,
    String? method,
    String? note,
  }) {
    return Payment(
      paymentId: paymentId,
      tutorId: tutorId,
      clientId: clientId,
      firebaseUid: firebaseUid ?? this.firebaseUid,
      sessionId: sessionId ?? this.sessionId,
      amount: amount ?? this.amount,
      currency: currency ?? this.currency,
      status: status ?? this.status,
      dueDate: dueDate ?? this.dueDate,
      paidDate: paidDate ?? this.paidDate,
      method: method ?? this.method,
      note: note ?? this.note,
      createdAt: createdAt,
      updatedAt: updatedAt,
    );
  }

  static String _ymd(DateTime d) =>
      '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

  /// Field map written to Firestore. Server timestamps for createdAt/updatedAt
  /// are added by the repository, not here.
  Map<String, dynamic> toJson() => {
        'paymentId': paymentId,
        'tutorId': tutorId,
        'clientId': clientId,
        if (firebaseUid != null) 'firebaseUid': firebaseUid,
        if (sessionId != null) 'sessionId': sessionId,
        'amount': amount,
        if (currency != null) 'currency': currency,
        'status': status.name,
        'dueDate': _ymd(dueDate),
        if (paidDate != null) 'paidDate': _ymd(paidDate!),
        if (method != null) 'method': method,
        if (note != null) 'note': note,
      };

  static DateTime? _parseDate(dynamic v) {
    if (v == null) return null;
    if (v is String) return DateTime.tryParse(v);
    // Firestore Timestamp duck-typing (avoids importing cloud_firestore here).
    try {
      final dt = (v as dynamic).toDate();
      if (dt is DateTime) return dt;
    } catch (_) {}
    return null;
  }

  factory Payment.fromJson(Map<String, dynamic> json, {String? id}) {
    return Payment(
      paymentId: (json['paymentId'] as String?) ?? id ?? '',
      tutorId: (json['tutorId'] as String?) ?? '',
      clientId: (json['clientId'] as String?) ?? '',
      firebaseUid: json['firebaseUid'] as String?,
      sessionId: json['sessionId'] as String?,
      amount: (json['amount'] as num?)?.toDouble() ?? 0,
      currency: json['currency'] as String?,
      status: PaymentStatus.fromName(json['status'] as String?),
      dueDate: _parseDate(json['dueDate']) ?? DateTime(1970),
      paidDate: _parseDate(json['paidDate']),
      method: json['method'] as String?,
      note: json['note'] as String?,
      createdAt: _parseDate(json['createdAt']),
      updatedAt: _parseDate(json['updatedAt']),
    );
  }
}
