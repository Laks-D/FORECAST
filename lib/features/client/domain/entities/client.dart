import 'client_timeline_event.dart';

class Client {
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
    this.currency,
    required this.timeline,
  });

  final String id;
  final String name;
  final String? middleName;
  final String primaryContact;
  final String? countryCode;
  final String? email;
  final String? gender;
  final DateTime? dateOfBirth;
  final String? address;
  final String? currency;
  final List<ClientTimelineEvent> timeline;

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

  /// Client status is user-controlled.
  ///
  /// The system must not automatically change status based on payments/schedule.
  /// We only honor explicit manual status changes made by the user.
  String get status {
    // Canonical, user-editable statuses.
    // NOTE: We also support legacy stored statuses via normalization below.
    const allowed = <String>{'Active', 'Pending', 'Inactive'};

    String? normalize(String raw) {
      final s = raw.trim();
      if (s.isEmpty) return null;
      final lower = s.toLowerCase();

      // Legacy mapping:
      // - "Overdue" is now displayed as "Pending".
      if (lower == 'overdue') return 'Pending';

      // Legacy mapping:
      // - "Upcoming" used to be a client status; it is no longer user-editable.
      //   Treat it as "Pending".
      if (lower == 'upcoming') return 'Pending';

      // Accept canonical values (case-insensitive).
      if (lower == 'active') return 'Active';
      if (lower == 'pending') return 'Pending';
      if (lower == 'inactive') return 'Inactive';

      // Unknown/unsupported status.
      return null;
    }

    DateTime? latestManualAt;
    String? latestManualStatus;
    for (final e in timeline) {
      if (e.type != ClientTimelineEventType.statusChanged) continue;
      final raw = e.status;
      if (raw == null) continue;
      final s = normalize(raw);
      if (s == null) continue;
      if (!allowed.contains(s)) continue;
      if (latestManualAt == null || e.createdAt.isAfter(latestManualAt)) {
        latestManualAt = e.createdAt;
        latestManualStatus = s;
      }
    }

    return (latestManualStatus != null && latestManualStatus.trim().isNotEmpty)
        ? latestManualStatus.trim()
      : 'Pending';
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
        if (currency != null) 'currency': currency,
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
      currency: json['currency'] as String?,
      timeline: (json['timeline'] as List<dynamic>?)
              ?.map((e) =>
                  ClientTimelineEvent.fromJson(e as Map<String, dynamic>))
              .toList() ??
          [],
    );
  }
}