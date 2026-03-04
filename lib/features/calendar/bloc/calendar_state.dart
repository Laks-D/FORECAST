import 'package:equatable/equatable.dart';

enum CalendarViewMode {
  weekly,
  monthly,
}

final class CalendarState extends Equatable {
  const CalendarState({
    required this.selectedDate,
    required this.viewMode,
    this.refreshNonce = 0,
    this.weeklyDaySelected = false,
  });

  final DateTime selectedDate;
  final CalendarViewMode viewMode;
  final int refreshNonce;
  /// True when the user explicitly tapped a day chip in weekly view.
  final bool weeklyDaySelected;

  CalendarState copyWith({DateTime? selectedDate, CalendarViewMode? viewMode, int? refreshNonce, bool? weeklyDaySelected}) {
    return CalendarState(
      selectedDate: selectedDate ?? this.selectedDate,
      viewMode: viewMode ?? this.viewMode,
      refreshNonce: refreshNonce ?? this.refreshNonce,
      weeklyDaySelected: weeklyDaySelected ?? this.weeklyDaySelected,
    );
  }

  @override
  List<Object?> get props => [
        DateTime(selectedDate.year, selectedDate.month, selectedDate.day),
        viewMode,
      refreshNonce,
      weeklyDaySelected,
      ];
}
