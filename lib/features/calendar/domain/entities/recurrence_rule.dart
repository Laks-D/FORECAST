/// Defines a recurring session series, stored at
/// `users/{tutorUid}/recurrence_rules/{recurrenceId}`.
///
/// Sessions generated from a rule carry the matching `recurrenceId`, so a whole
/// series can be edited/deleted by reference instead of duplicating rows.
class RecurrenceRule {
  const RecurrenceRule({
    required this.recurrenceId,
    required this.tutorId,
    required this.clientId,
    this.programId,
    required this.frequency, // daily | weekly | custom
    this.interval = 1,
    this.byWeekday = const [],
    required this.startDate,
    this.endDate,
    required this.time,
  });

  final String recurrenceId;
  final String tutorId;
  final String clientId;
  final String? programId;
  final String frequency;
  final int interval;
  final List<int> byWeekday; // 0=Mon ... 6=Sun
  final DateTime startDate;
  final DateTime? endDate;
  final String time; // HH:mm

  static String _ymd(DateTime d) =>
      '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

  Map<String, dynamic> toJson() => {
        'recurrenceId': recurrenceId,
        'tutorId': tutorId,
        'clientId': clientId,
        if (programId != null) 'programId': programId,
        'frequency': frequency,
        'interval': interval,
        'byWeekday': byWeekday,
        'startDate': _ymd(startDate),
        if (endDate != null) 'endDate': _ymd(endDate!),
        'time': time,
      };

  static DateTime _date(dynamic v) {
    if (v is String) return DateTime.tryParse(v) ?? DateTime(1970);
    try {
      final dt = (v as dynamic).toDate();
      if (dt is DateTime) return dt;
    } catch (_) {}
    return DateTime(1970);
  }

  factory RecurrenceRule.fromJson(Map<String, dynamic> json, {String? id}) {
    return RecurrenceRule(
      recurrenceId: (json['recurrenceId'] as String?) ?? id ?? '',
      tutorId: (json['tutorId'] as String?) ?? '',
      clientId: (json['clientId'] as String?) ?? '',
      programId: json['programId'] as String?,
      frequency: (json['frequency'] as String?) ?? 'weekly',
      interval: (json['interval'] as num?)?.toInt() ?? 1,
      byWeekday: (json['byWeekday'] as List<dynamic>?)
              ?.map((e) => (e as num).toInt())
              .toList() ??
          const [],
      startDate: _date(json['startDate']),
      endDate: json['endDate'] != null ? _date(json['endDate']) : null,
      time: (json['time'] as String?) ?? '00:00',
    );
  }
}
