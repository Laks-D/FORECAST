// Removed legacy ProgramType enum

extension SessionDurationExtension on SessionDuration {
  String get displayName {
    switch (this) {
      case SessionDuration.halfHour:
        return '0.5 Hour';
      case SessionDuration.oneHour:
        return '1 Hour';
      case SessionDuration.twoHours:
        return '2 Hours';
      case SessionDuration.threeHours:
        return '3 Hours';
      case SessionDuration.wholeDay:
        return 'Whole Day';
    }
  }

  double get hours {
    switch (this) {
      case SessionDuration.halfHour:
        return 0.5;
      case SessionDuration.oneHour:
        return 1.0;
      case SessionDuration.twoHours:
        return 2.0;
      case SessionDuration.threeHours:
        return 3.0;
      case SessionDuration.wholeDay:
        return 8.0;
    }
  }
}

class ScheduleSession {
  bool notifiedTwoHour;
  bool notifiedFiveMin;
  bool read;

  final int id;
  final String clientId;
  final String status;
  final int sessionNo;
  final String time;
  final String date; // yyyy-MM-dd

  final int? rating;
  final String? comments;
  final String? courseName;
  final SessionDuration? duration;
  final String? programEnrollmentId;

  ScheduleSession({
    required this.id,
    required this.clientId,
    required this.status,
    required this.sessionNo,
    required this.time,
    required this.date,
    this.rating,
    this.comments,
    this.read = false,
    this.notifiedTwoHour = false,
    this.notifiedFiveMin = false,
    this.courseName,
    this.duration,
    this.programEnrollmentId,
  });

  ScheduleSession copyWith({
    bool? notifiedTwoHour,
    bool? notifiedFiveMin,
    bool? read,
    String? time,
    String? date,
    String? status,
    int? rating,
    String? comments,
    SessionDuration? duration,
  }) {
    return ScheduleSession(
      id: id,
      clientId: clientId,
      status: status ?? this.status,
      sessionNo: sessionNo,
      time: time ?? this.time,
      date: date ?? this.date,
      rating: rating ?? this.rating,
      comments: comments ?? this.comments,
      read: read ?? this.read,
      notifiedTwoHour: notifiedTwoHour ?? this.notifiedTwoHour,
      notifiedFiveMin: notifiedFiveMin ?? this.notifiedFiveMin,
      courseName: courseName,
      duration: duration ?? this.duration,
      programEnrollmentId: programEnrollmentId,
    );
  }

  /* ================= SERIALIZATION ================= */

  Map<String, dynamic> toJson() => {
        'id': id,
        'clientId': clientId,
        'status': status,
        'sessionNo': sessionNo,
        'time': time,
        'date': date,
        if (rating != null) 'rating': rating,
        if (comments != null) 'comments': comments,
        'read': read,
        'notifiedTwoHour': notifiedTwoHour,
        'notifiedFiveMin': notifiedFiveMin,
        if (courseName != null) 'courseName': courseName,
        if (duration != null) 'duration': duration!.name,
        if (programEnrollmentId != null)
          'programEnrollmentId': programEnrollmentId,
      };

  factory ScheduleSession.fromJson(Map<String, dynamic> json) {
    return ScheduleSession(
      id: json['id'] as int,
      clientId: json['clientId'] as String,
      status: json['status'] as String,
      sessionNo: json['sessionNo'] as int,
      time: json['time'] as String,
      date: json['date'] as String,
      rating: json['rating'] as int?,
      comments: json['comments'] as String?,
      read: (json['read'] as bool?) ?? false,
      notifiedTwoHour: (json['notifiedTwoHour'] as bool?) ?? false,
      notifiedFiveMin: (json['notifiedFiveMin'] as bool?) ?? false,
      courseName: (json['courseName'] as String?) ?? _mapLegacyProgramType(json['programType'] as String?),
      duration: json['duration'] != null
          ? SessionDuration.values.firstWhere(
              (e) => e.name == json['duration'],
              orElse: () => SessionDuration.oneHour,
            )
          : null,
      programEnrollmentId: json['programEnrollmentId'] as String?,
    );
  }

  static String? _mapLegacyProgramType(String? legacyName) {
    if (legacyName == null) return null;
    switch (legacyName) {
      case 'gbp':
        return 'GBP';
      case 'payanam':
        return 'Payanam';
      case 'ninertia':
        return 'Ninertia';
      case 'becoming':
        return 'Becoming';
      case 'happyHuddle':
        return 'Happy Huddle';
      case 'oneToOneLifeCoaching':
        return '1:1 Life Coaching';
      default:
        return legacyName;
    }
  }
}
