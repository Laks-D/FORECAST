class AppDateUtils {
  static int parseTimeLabel(String label) {
    var s = label.trim();
    if (s.isEmpty) return 0;

    final upper = s.toUpperCase();
    final isPm = upper.contains('PM');
    final isAm = upper.contains('AM');

    // Remove AM/PM/whitespace and keep HH:mm.
    final timePart = s.replaceAll(RegExp(r'[ A-Za-z]'), '');
    final hm = timePart.split(':');
    if (hm.length < 2) return 0;

    var h = int.tryParse(hm[0]) ?? 0;
    final m = int.tryParse(hm[1]) ?? 0;

    if (isPm && h < 12) h += 12;
    if (isAm && h == 12) h = 0;

    return h * 60 + m;
  }

  static String formatTimeLabelFromMinutes(int minutes) {
    final normalized = minutes % (24 * 60);
    final h24 = normalized ~/ 60;
    final m = normalized % 60;
    final isPm = h24 >= 12;
    var h12 = h24 % 12;
    if (h12 == 0) h12 = 12;

    return '${h12.toString().padLeft(2, '0')}:${m.toString().padLeft(2, '0')} ${isPm ? 'PM' : 'AM'}';
  }

  static String formatTimeRangeFromStartAndDuration({
    required String startLabel,
    required int durationMinutes,
  }) {
    final startMinutes = parseTimeLabel(startLabel);
    final endMinutes = startMinutes + durationMinutes;
    final start = formatTimeLabelFromMinutes(startMinutes);
    final end = formatTimeLabelFromMinutes(endMinutes);
    return '$start - $end';
  }

  static String dateToStr(DateTime d) {
    return '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
  }

  /// User-facing date string in dd-MM-yyyy format.
  static String displayDate(DateTime d) {
    return '${d.day.toString().padLeft(2, '0')}-${d.month.toString().padLeft(2, '0')}-${d.year.toString().padLeft(4, '0')}';
  }

  /// Convert an internal dateToStr key to display format.
  static String displayDateStr(String dateStr) {
    final d = parseSessionDate(dateStr);
    return displayDate(d);
  }

  static DateTime parseSessionDate(String dateStr) {
    // Supports ISO strings and our default yyyy-MM-dd format.
    return DateTime.parse(dateStr);
  }

  static Map<String, int> parseTimeRange(String timeRange) {
    // Normalize string: ensure space around hyphens, remove extra spaces.
    var cleaned = timeRange.replaceAll(RegExp(r'\s+'), ' ').trim();
    if (!cleaned.contains(' - ') && cleaned.contains('-')) {
      cleaned = cleaned.replaceAll('-', ' - ');
    }

    final parts = cleaned.split(' - ');
    if (parts.length < 2) return {'start': 0, 'end': 0};

    final start = parseTimeLabel(parts[0]);
    var end = parseTimeLabel(parts[1]);
    if (end < start) {
      // Treat ranges like "11:00 PM - 01:00 AM" as crossing midnight.
      end += 24 * 60;
    }

    return {
      'start': start,
      'end': end,
    };
  }

  static String determineSessionStatus(
    String currentStatus,
    String dateStr,
    String timeStr,
  ) {
    // Explicit statuses always win.
    if (currentStatus == 'Completed' || currentStatus == 'Cancelled') return currentStatus;
    if (currentStatus == 'Overdue') return 'Overdue';

    try {
      final now = DateTime.now();
      final todayDate = DateTime(now.year, now.month, now.day);
      final nowInMinutes = now.hour * 60 + now.minute;

      final sessionDate = parseSessionDate(dateStr);
      final sessionOnlyDate =
          DateTime(sessionDate.year, sessionDate.month, sessionDate.day);

      if (sessionOnlyDate.isBefore(todayDate)) {
        return 'Overdue';
      } else if (sessionOnlyDate.isAfter(todayDate)) {
        return 'Pending';
      } else {
        final range = parseTimeRange(timeStr);
        final startMinutes = range['start'] ?? 0;
        final endMinutes = range['end'] ?? startMinutes;

        // If the session already ended and isn't completed, it is overdue.
        if (nowInMinutes >= endMinutes) return 'Overdue';
        return 'Pending';
      }
    } catch (_) {
      return currentStatus;
    }
  }
}
