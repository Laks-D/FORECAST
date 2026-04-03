import '../../../../core/utils/date_utils.dart';
import '../entities/schedule_session.dart';

class ScheduleGenerator {
  static List<ScheduleSession> generate({
    required int count,
    required DateTime startDate,
    required String frequency, // Daily | Weekly | Monthly | Custom
    required String timeSlot, // "10:00 AM" or "10:00 AM - 11:00 AM"
    required int weeklyDay, // DateTime.monday..sunday
    required int monthlyDate,
    required String clientId,
    int customDays = 1,
    SessionDuration? duration,
    ProgramType? programType,
    String? courseName,
    String? programEnrollmentId,
  }) {
    final sessions = <ScheduleSession>[];
    var cursor = DateTime(startDate.year, startDate.month, startDate.day);

    final timeRange = _resolveTimeRange(timeSlot, duration);

    if (frequency == 'Weekly') {
      while (cursor.weekday != weeklyDay) {
        cursor = cursor.add(const Duration(days: 1));
      }
    } else if (frequency == 'Monthly') {
      if (cursor.day > monthlyDate) {
        cursor = DateTime(cursor.year, cursor.month + 1, monthlyDate);
      } else {
        cursor = DateTime(cursor.year, cursor.month, monthlyDate);
      }

      if (cursor.isBefore(startDate)) {
        cursor = DateTime(cursor.year, cursor.month + 1, monthlyDate);
      }
    }

    for (var i = 0; i < count; i++) {
      sessions.add(
        ScheduleSession(
          id: DateTime.now().millisecondsSinceEpoch + i,
          sessionNo: i + 1,
          clientId: clientId,
          status: 'Upcoming',
          time: timeRange,
          date: AppDateUtils.dateToStr(cursor),
          duration: duration,
          programType: programType,
          courseName: courseName,
          programEnrollmentId: programEnrollmentId,
        ),
      );

      if (frequency == 'Daily') {
        cursor = cursor.add(const Duration(days: 1));
      } else if (frequency == 'Weekly') {
        cursor = cursor.add(const Duration(days: 7));
      } else if (frequency == 'Monthly') {
        cursor = DateTime(cursor.year, cursor.month + 1, monthlyDate);
      } else if (frequency == 'Custom') {
        final step = customDays <= 0 ? 1 : customDays;
        cursor = cursor.add(Duration(days: step));
      }
    }

    return sessions;
  }

  static String _resolveTimeRange(String timeSlot, SessionDuration? duration) {
    // Backwards compatibility: if already a range, keep it.
    if (timeSlot.contains('-')) {
      final cleaned = timeSlot.replaceAll(RegExp(r'\s+'), ' ').trim();
      return cleaned.contains(' - ') ? cleaned : cleaned.replaceAll('-', ' - ');
    }

    final minutes = (((duration ?? SessionDuration.oneHour).hours) * 60).round();
    return AppDateUtils.formatTimeRangeFromStartAndDuration(
      startLabel: timeSlot,
      durationMinutes: minutes,
    );
  }

  /// Returns a set of draft session IDs that clash with existing sessions.
  static Set<int> findClashes(
    List<ScheduleSession> draft,
    List<ScheduleSession> existing,
  ) {
    final clashIds = <int>{};

    for (final newS in draft) {
      final newTime = AppDateUtils.parseTimeRange(newS.time);
      for (final ex in existing) {
        if (newS.date != ex.date) continue;
        // Cancelled/Completed sessions should not block scheduling.
        final derived = AppDateUtils.determineSessionStatus(ex.status, ex.date, ex.time);
        if (derived == 'Cancelled' || derived == 'Completed') continue;
        final exTime = AppDateUtils.parseTimeRange(ex.time);

        final overlaps = (newTime['start']! < exTime['end']!) &&
            (newTime['end']! > exTime['start']!);
        if (overlaps) {
          clashIds.add(newS.id);
          break;
        }
      }
    }

    return clashIds;
  }
}
