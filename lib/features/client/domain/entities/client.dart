import 'client_timeline_event.dart';

class Client {
  final String id;
  final String name;
  final String? middleName;
  final String primaryContact;
  final String? countryCode;
  final String? email;
  final String? gender;
  final DateTime? dateOfBirth;
  final String? address;
  final List<ClientTimelineEvent> timeline;

  const Client({
    required this.id,
    required this.name,
    this.middleName,
    required this.primaryContact,
    this.countryCode,
    this.email,
    this.gender,
    this.dateOfBirth,
    this.address,
    required this.timeline,
  });

  /// Full display name including middle name if present.
  String get displayName {
    if (middleName != null && middleName!.trim().isNotEmpty) {
      return '${name.split(' ').first} ${middleName!.trim()} ${name.split(' ').length > 1 ? name.split(' ').sublist(1).join(' ') : ''}'.trim();
    }
    return name;
  }

  /// Phone number with country code prefix.
  String get formattedPhone {
    var code = (countryCode != null && countryCode!.isNotEmpty) ? countryCode! : '+91';
    if (!code.startsWith('+')) code = '+$code';
    return '$code $primaryContact';
  }

  /* ================= PAYMENTS ================= */

  /// Filters the timeline for payment-specific events.
    List<ClientTimelineEvent> get payments =>
      timeline.where((e) => e.type == ClientTimelineEventType.payment).toList();

  /// Calculates total volume of payments processed.
  double get outstandingAmount =>
      payments.fold(0, (sum, e) => sum + (e.amount ?? 0));

  /* ================= STATUS ================= */

  /// Determines the entity status based on payment history and due dates.
  ///
  /// Priority:
  /// 1. If the most recent timeline event overall is a manual status change, use it.
  /// 2. Otherwise auto-compute from payments:
  ///    - No payments → "Pending"
  ///    - Any payment overdue (past date, not marked Paid/Paid fully) → "Overdue"
  ///    - Has at least one Paid payment and no overdue → "Active"
  ///    - All future, none paid → "Pending"
  String get status {
    // 1. Check for a manual override (latest timeline event is a statusChanged).
    if (timeline.isNotEmpty) {
      final latest = timeline.reduce(
        (a, b) => a.createdAt.isAfter(b.createdAt) ? a : b,
      );
      if (latest.type == ClientTimelineEventType.statusChanged &&
          (latest.status?.trim().isNotEmpty ?? false)) {
        return latest.status!;
      }
    }

    // 2. Auto-compute from payment events.
    if (payments.isEmpty) return 'Pending';

    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);

    bool hasPaid = false;
    bool hasOverdue = false;

    for (final pay in payments) {
      final payDate = DateTime(pay.createdAt.year, pay.createdAt.month, pay.createdAt.day);
      final dateKey = '${pay.createdAt.year}-${pay.createdAt.month.toString().padLeft(2, '0')}-${pay.createdAt.day.toString().padLeft(2, '0')}';

      // Check if this payment date has a Paid / Paid fully status event
      bool isPaid = false;
      for (final e in timeline.reversed) {
        if (e.type != ClientTimelineEventType.statusChanged) continue;
        final eKey = '${e.createdAt.year}-${e.createdAt.month.toString().padLeft(2, '0')}-${e.createdAt.day.toString().padLeft(2, '0')}';
        if (eKey != dateKey) continue;
        final s = e.status?.trim();
        if (s == 'Paid' || s == 'Paid fully') {
          isPaid = true;
          break;
        }
      }

      if (isPaid) {
        hasPaid = true;
      } else if (payDate.isBefore(today) || payDate.isAtSameMomentAs(today)) {
        hasOverdue = true;
      }
    }

    if (hasOverdue) return 'Overdue';
    if (hasPaid) return 'Active';

    // All payments are in the future and none paid yet
    return 'Pending';
  }

  /// Returns the timestamp of the most recent event in the timeline.
  DateTime? get lastActivityAt =>
      timeline.isEmpty ? null : timeline.last.createdAt;

  /* ================= SERIALIZATION ================= */

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        if (middleName != null) 'middleName': middleName,
        'primaryContact': primaryContact,
        if (countryCode != null) 'countryCode': countryCode,
        if (email != null) 'email': email,
        if (gender != null) 'gender': gender,
        if (dateOfBirth != null) 'dateOfBirth': dateOfBirth!.toIso8601String(),
        if (address != null) 'address': address,
        'timeline': timeline.map((e) => e.toJson()).toList(),
      };

  factory Client.fromJson(Map<String, dynamic> json) {
    return Client(
      id: json['id'] as String,
      name: json['name'] as String,
      middleName: json['middleName'] as String?,
      primaryContact: json['primaryContact'] as String,
      countryCode: json['countryCode'] as String?,
      email: json['email'] as String?,
      gender: json['gender'] as String?,
      dateOfBirth: json['dateOfBirth'] != null
          ? DateTime.tryParse(json['dateOfBirth'] as String)
          : null,
      address: json['address'] as String?,
      timeline: (json['timeline'] as List<dynamic>?)
              ?.map((e) =>
                  ClientTimelineEvent.fromJson(e as Map<String, dynamic>))
              .toList() ??
          [],
    );
  }
}