import 'package:bloc/bloc.dart';

import 'calendar_state.dart';

class CalendarCubit extends Cubit<CalendarState> {
  CalendarCubit()
      : super(
          CalendarState(
            selectedDate: DateTime.now(),
            viewMode: CalendarViewMode.monthly,
            refreshNonce: 0,
          ),
        );

  void setViewMode(CalendarViewMode mode) {
    if (state.viewMode == mode) return;
    emit(state.copyWith(viewMode: mode, weeklyDaySelected: false));
  }

  void selectDate(DateTime date, {bool explicit = false}) {
    final normalized = DateTime(date.year, date.month, date.day);
    final current = DateTime(state.selectedDate.year, state.selectedDate.month, state.selectedDate.day);
    if (normalized == current && explicit == (state.weeklyDaySelected == true)) return;
    emit(state.copyWith(
      selectedDate: normalized,
      weeklyDaySelected: explicit,
    ));
  }

  void goToPrevious() {
    if (state.viewMode == CalendarViewMode.weekly) {
      selectDate(state.selectedDate.subtract(const Duration(days: 7)));
      return;
    }
    selectDate(_shiftMonth(state.selectedDate, -1));
  }

  void goToNext() {
    if (state.viewMode == CalendarViewMode.weekly) {
      selectDate(state.selectedDate.add(const Duration(days: 7)));
      return;
    }
    selectDate(_shiftMonth(state.selectedDate, 1));
  }

  /// Clear the day-specific filter in weekly view (show full week again).
  void clearWeeklyDaySelection() {
    if (!state.weeklyDaySelected) return;
    emit(state.copyWith(weeklyDaySelected: false));
  }

  /// Force a refresh by re-emitting the current state.
  /// Useful when external data changed and UI needs to rebuild.
  void refresh() {
    emit(state.copyWith(refreshNonce: state.refreshNonce + 1));
  }

  static DateTime _shiftMonth(DateTime date, int deltaMonths) {
    final target = DateTime(date.year, date.month + deltaMonths, 1);
    final daysInTargetMonth = _daysInMonth(target.year, target.month);
    final clampedDay = date.day.clamp(1, daysInTargetMonth);
    return DateTime(target.year, target.month, clampedDay);
  }

  static int _daysInMonth(int year, int month) {
    final firstOfNextMonth = (month == 12) ? DateTime(year + 1, 1, 1) : DateTime(year, month + 1, 1);
    return firstOfNextMonth.subtract(const Duration(days: 1)).day;
  }
}
