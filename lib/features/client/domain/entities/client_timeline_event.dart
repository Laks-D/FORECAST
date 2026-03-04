enum ClientTimelineEventType {
  profileCreated,
  statusChanged,
  payment,
  note,
}

class ClientTimelineEvent {
  final String id;
  final ClientTimelineEventType type;
  final DateTime createdAt;

  // Optional payload
  final double? amount;
  final String? note;
  final String? status;

  const ClientTimelineEvent({
    required this.id,
    required this.type,
    required this.createdAt,
    this.amount,
    this.note,
    this.status,
  });

  /* ================= COMPUTED FIELDS ================= */

  /// Human-readable title for UI
  String get title {
    switch (type) {
      case ClientTimelineEventType.profileCreated:
        return 'Profile created';
      case ClientTimelineEventType.statusChanged:
        return 'Status changed';
      case ClientTimelineEventType.payment:
        return 'Payment received';
      case ClientTimelineEventType.note:
        return 'Note added';
    }
  }

  /// Secondary text shown in lists / timelines
  String? get description {
    switch (type) {
      case ClientTimelineEventType.profileCreated:
        return null;
      case ClientTimelineEventType.statusChanged:
        return status;
      case ClientTimelineEventType.payment:
        if (amount == null) return null;
        return '₹$amount';
      case ClientTimelineEventType.note:
        return note;
    }
  }

  /// Flexible structured data (future-proof)
  Map<String, dynamic> get metadata {
    return {
      if (amount != null) 'amount': amount,
      if (note != null) 'note': note,
      if (status != null) 'status': status,
    };
  }

  /* ================= FACTORIES ================= */

  factory ClientTimelineEvent.profileCreated({
    required String id,
    required DateTime createdAt,
  }) {
    return ClientTimelineEvent(
      id: id,
      type: ClientTimelineEventType.profileCreated,
      createdAt: createdAt,
    );
  }

  factory ClientTimelineEvent.statusChange({
    required String id,
    required String status,
    required DateTime createdAt,
  }) {
    return ClientTimelineEvent(
      id: id,
      type: ClientTimelineEventType.statusChanged,
      status: status,
      createdAt: createdAt,
    );
  }

  factory ClientTimelineEvent.payment({
    required String id,
    required double amount,
    required DateTime createdAt,
    String? note,
  }) {
    return ClientTimelineEvent(
      id: id,
      type: ClientTimelineEventType.payment,
      amount: amount,
      note: note,
      createdAt: createdAt,
    );
  }

  factory ClientTimelineEvent.note({
    required String id,
    required String note,
    required DateTime createdAt,
  }) {
    return ClientTimelineEvent(
      id: id,
      type: ClientTimelineEventType.note,
      note: note,
      createdAt: createdAt,
    );
  }

  /* ================= SERIALIZATION ================= */

  Map<String, dynamic> toJson() => {
        'id': id,
        'type': type.name,
        'createdAt': createdAt.toIso8601String(),
        if (amount != null) 'amount': amount,
        if (note != null) 'note': note,
        if (status != null) 'status': status,
      };

  factory ClientTimelineEvent.fromJson(Map<String, dynamic> json) {
    return ClientTimelineEvent(
      id: json['id'] as String,
      type: ClientTimelineEventType.values.firstWhere(
        (e) => e.name == json['type'],
        orElse: () => ClientTimelineEventType.note,
      ),
      createdAt: DateTime.parse(json['createdAt'] as String),
      amount: (json['amount'] as num?)?.toDouble(),
      note: json['note'] as String?,
      status: json['status'] as String?,
    );
  }
}