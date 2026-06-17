
class Client {
  const Client({
    required this.id,
    this.tutorId,
    this.firebaseUid,
    required this.name,
    this.middleName,
    required this.primaryContact,
    this.countryCode,
    this.email,
    this.gender,
    this.dateOfBirth,
    this.address,
    this.currency,
    required this.status,
    this.pinned = false,
    this.deletedAt,
  });

  final String id;
  final String? tutorId;
  final String? firebaseUid;
  final String name;
  final String? middleName;
  final String primaryContact;
  final String? countryCode;
  final String? email;
  final String? gender;
  final DateTime? dateOfBirth;
  final String? address;
  final String? currency;
  final String status;
  final bool pinned;

  /// Timestamp when the client was soft-deleted. Used for 30-day auto-purge.
  final DateTime? deletedAt;

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



  /* ================= SERIALIZATION ================= */

  Map<String, dynamic> toJson() => {
        'id': id,
      if (firebaseUid != null) 'firebaseUid': firebaseUid,
        'name': name,
        if (middleName != null) 'middleName': middleName,
        'primaryContact': primaryContact,
        if (countryCode != null) 'countryCode': countryCode,
        if (email != null) 'email': email,
        if (gender != null) 'gender': gender,
        if (dateOfBirth != null) 'dateOfBirth': dateOfBirth!.toIso8601String(),
        if (address != null) 'address': address,
        if (currency != null) 'currency': currency,
        'status': status,
        'pinned': pinned,
        if (deletedAt != null) 'deletedAt': deletedAt!.toIso8601String(),
      };

  factory Client.fromJson(Map<String, dynamic> json) {
    return Client(
      id: json['id'] as String,
      tutorId: json['tutorId'] as String?,
      firebaseUid: json['firebaseUid'] as String?,
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
      status: (json['status'] as String?) ?? 'Pending',
      pinned: (json['pinned'] as bool?) ?? false,
      deletedAt: json['deletedAt'] != null
          ? DateTime.tryParse(json['deletedAt'] as String)
          : null,
    );
  }
}