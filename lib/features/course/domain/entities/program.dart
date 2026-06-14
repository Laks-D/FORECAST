/// A reusable class template, stored at `users/{tutorUid}/programs/{programId}`.
///
/// Promotes the legacy `programCatalog[]` settings array to a first-class
/// collection. Keeps every field the existing `RegisteredProgram` carried (so
/// no data is lost) and adds identity (programId, tutorId).
class Program {
  const Program({
    required this.programId,
    required this.tutorId,
    required this.name,
    this.description = '',
    this.frequency = 'Weekly',
    this.numberOfClasses = 8,
    this.classDuration = '1 Hour',
    this.customDays = 1,
    this.pinned = false,
    this.createdAt,
  });

  final String programId;
  final String tutorId;
  final String name;
  final String description;
  final String frequency;
  final int numberOfClasses;
  final String classDuration;
  final int customDays;
  final bool pinned;
  final DateTime? createdAt;

  /// Stable doc id derived from the name (idempotent re-saves).
  static String slug(String name) {
    var v = name.trim().toLowerCase().replaceAll(RegExp(r'[^a-z0-9]+'), '_');
    v = v.replaceAll(RegExp(r'_+'), '_').replaceAll(RegExp(r'^_+|_+$'), '');
    return v.isEmpty ? 'program' : v;
  }

  Map<String, dynamic> toJson() => {
        'programId': programId,
        'tutorId': tutorId,
        'name': name,
        'description': description,
        'frequency': frequency,
        'numberOfClasses': numberOfClasses,
        'classDuration': classDuration,
        'customDays': customDays,
        'pinned': pinned,
      };

  static DateTime? _date(dynamic v) {
    if (v is String) return DateTime.tryParse(v);
    try {
      final dt = (v as dynamic).toDate();
      if (dt is DateTime) return dt;
    } catch (_) {}
    return null;
  }

  factory Program.fromJson(Map<String, dynamic> json, {String? id}) {
    final name = (json['name'] as String? ?? '').trim();
    return Program(
      programId: (json['programId'] as String?) ?? id ?? slug(name),
      tutorId: (json['tutorId'] as String?) ?? '',
      name: name,
      description: (json['description'] as String? ?? '').trim(),
      frequency: (json['frequency'] as String? ?? 'Weekly').trim(),
      numberOfClasses: (json['numberOfClasses'] as num?)?.toInt() ?? 8,
      classDuration: (json['classDuration'] as String? ?? '1 Hour').trim(),
      customDays: (json['customDays'] as num?)?.toInt() ?? 1,
      pinned: json['pinned'] as bool? ?? false,
      createdAt: _date(json['createdAt']),
    );
  }
}
