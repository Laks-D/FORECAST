import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter/services.dart';

import '../../../../core/di/service_locator.dart';
import '../../../../core/utils/date_utils.dart';
import '../../../../design_system/theme/app_chrome_theme.dart';
import '../../../client/domain/entities/client.dart';
import '../../../client/domain/usecases/get_clients_usecase.dart';
import '../../../client/domain/entities/client_timeline_event.dart';
import '../../../client/presentation/bloc/client_bloc.dart';
import '../../../client/presentation/bloc/client_event.dart';
import '../../bloc/calendar_cubit.dart';
import '../../bloc/calendar_state.dart';
import '../../bloc/sessions_cubit.dart';
import '../../domain/entities/schedule_session.dart';
import 'schedule_sessions_sheet.dart';

enum _ScheduleCalendarType {
  classSchedule,
  paymentSchedule,
}

class CalendarPageBody extends StatefulWidget {
  const CalendarPageBody({super.key});

  @override
  State<CalendarPageBody> createState() => _CalendarPageBodyState();

  static const _cardRadius = 40.0;
  static const _softText = Color(0xFF4A4A4A);

  static DateTime _startOfWeek(DateTime date) {
    final normalized = DateTime(date.year, date.month, date.day);
    return normalized.subtract(Duration(days: normalized.weekday - 1));
  }

  static String _monthName(int month) {
    const months = [
      'JAN',
      'FEB',
      'MAR',
      'APR',
      'MAY',
      'JUN',
      'JUL',
      'AUG',
      'SEP',
      'OCT',
      'NOV',
      'DEC'
    ];
    return months[month - 1];
  }
}

class _CalendarPageBodyState extends State<CalendarPageBody> {
  _ScheduleCalendarType _scheduleType = _ScheduleCalendarType.classSchedule;

  @override
  Widget build(BuildContext context) {
    return BlocSelector<CalendarCubit, CalendarState, CalendarViewMode>(
      selector: (s) => s.viewMode,
      builder: (context, mode) {
        final topFlex = mode == CalendarViewMode.monthly ? 5 : 3;
        final bottomFlex = mode == CalendarViewMode.monthly ? 6 : 8;

        return Column(
          children: [
            Flexible(
              flex: topFlex,
              child: _CalendarTopCard(
                mode: mode,
                scheduleType: _scheduleType,
              ),
            ),
            const SizedBox(height: 8),
            _ScheduleTypeToggle(
              value: _scheduleType,
              onChanged: (type) => setState(() => _scheduleType = type),
            ),
            const SizedBox(height: 12),
            Flexible(
              flex: bottomFlex,
              child: _CalendarBottomCard(scheduleType: _scheduleType),
            ),
          ],
        );
      },
    );
  }
}

class _ScheduleTypeToggle extends StatelessWidget {
  const _ScheduleTypeToggle({
    required this.value,
    required this.onChanged,
  });

  final _ScheduleCalendarType value;
  final ValueChanged<_ScheduleCalendarType> onChanged;

  @override
  Widget build(BuildContext context) {
    Widget pill({
      required String text,
      required bool selected,
      required VoidCallback onTap,
    }) {
      return InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(999),
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: selected ? const Color(0xFFEFEFEF) : Colors.transparent,
            borderRadius: BorderRadius.circular(999),
            border: selected ? Border.all(color: const Color(0xFFE1E1E1)) : null,
          ),
          child: SizedBox(
            height: 44,
            child: Center(
              child: Text(
                text,
                style: TextStyle(
                  color: selected ? Colors.black : Colors.grey,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ),
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(999),
          border: Border.all(color: const Color(0xFFE6E6E6)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.max,
          children: [
            Expanded(
              child: pill(
                text: 'Class Schedule',
                selected: value == _ScheduleCalendarType.classSchedule,
                onTap: () => onChanged(_ScheduleCalendarType.classSchedule),
              ),
            ),
            Expanded(
              child: pill(
                text: 'Payment Schedule',
                selected: value == _ScheduleCalendarType.paymentSchedule,
                onTap: () => onChanged(_ScheduleCalendarType.paymentSchedule),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _CalendarTopCard extends StatelessWidget {
  const _CalendarTopCard({
    required this.mode,
    required this.scheduleType,
  });

  final CalendarViewMode mode;
  final _ScheduleCalendarType scheduleType;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(CalendarPageBody._cardRadius),
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: _CalendarHeader(mode: mode),
                ),
                const SizedBox(width: 10),
                const _CalendarModeToggle(),
              ],
            ),
            const SizedBox(height: 12),
            Expanded(
              child: mode == CalendarViewMode.weekly
                  ? _WeeklyTopContent(
                      key: const ValueKey('weekly'),
                      scheduleType: scheduleType,
                    )
                  : _MonthlyTopContent(
                      key: const ValueKey('monthly'),
                      scheduleType: scheduleType,
                    ),
            ),
          ],
        ),
      ),
    );
  }
}

class _CalendarHeader extends StatelessWidget {
  const _CalendarHeader({required this.mode});

  final CalendarViewMode mode;

  @override
  Widget build(BuildContext context) {
    return BlocSelector<CalendarCubit, CalendarState, DateTime>(
      selector: (s) => s.selectedDate,
      builder: (context, selected) {
        final title = '${CalendarPageBody._monthName(selected.month)} ${selected.year}';

        return SizedBox(
          height: 28,
          child: Row(
            children: [
              _ArrowButton(
                icon: Icons.chevron_left,
                onTap: () => context.read<CalendarCubit>().goToPrevious(),
              ),
              Expanded(
                child: Center(
                  child: Text(
                    title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.labelLarge?.copyWith(
                          color: CalendarPageBody._softText,
                          fontWeight: FontWeight.w800,
                        ),
                  ),
                ),
              ),
              _ArrowButton(
                icon: Icons.chevron_right,
                onTap: () => context.read<CalendarCubit>().goToNext(),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _ArrowButton extends StatelessWidget {
  const _ArrowButton({required this.icon, required this.onTap});

  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(999),
      child: Padding(
        padding: const EdgeInsets.all(4),
        child: Icon(
          icon,
          size: 20,
          color: Colors.black54,
        ),
      ),
    );
  }
}

class _CalendarModeToggle extends StatelessWidget {
  const _CalendarModeToggle();

  @override
  Widget build(BuildContext context) {
    return BlocSelector<CalendarCubit, CalendarState, CalendarViewMode>(
      selector: (s) => s.viewMode,
      builder: (context, mode) {
        Widget pill({required String text, required bool selected, required VoidCallback onTap}) {
          return InkWell(
            onTap: onTap,
            borderRadius: BorderRadius.circular(999),
            child: DecoratedBox(
              decoration: BoxDecoration(
                color: selected ? const Color(0xFFEFEFEF) : Colors.transparent,
                borderRadius: BorderRadius.circular(999),
                border: selected ? Border.all(color: const Color(0xFFE1E1E1)) : null,
              ),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
                child: Text(
                  text,
                  style: Theme.of(context).textTheme.labelSmall?.copyWith(
                        color: selected ? Colors.black87 : Colors.black54,
                        fontWeight: FontWeight.w700,
                      ),
                ),
              ),
            ),
          );
        }

        return DecoratedBox(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(999),
            border: Border.all(color: const Color(0xFFE6E6E6)),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const SizedBox(width: 2),
              pill(
                text: 'Weekly',
                selected: mode == CalendarViewMode.weekly,
                onTap: () => context.read<CalendarCubit>().setViewMode(CalendarViewMode.weekly),
              ),
              pill(
                text: 'Monthly',
                selected: mode == CalendarViewMode.monthly,
                onTap: () => context.read<CalendarCubit>().setViewMode(CalendarViewMode.monthly),
              ),
              const SizedBox(width: 2),
            ],
          ),
        );
      },
    );
  }
}

class _WeeklyTopContent extends StatelessWidget {
  const _WeeklyTopContent({
    super.key,
    required this.scheduleType,
  });

  final _ScheduleCalendarType scheduleType;

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<SessionsCubit, SessionsState>(
      builder: (context, sessionsState) {
        return BlocBuilder<CalendarCubit, CalendarState>(
          builder: (context, calendarState) {
            final Set<String> markerDates;
            final Map<String, int> sessionCounts = {};
            final Map<String, bool> allCompletedMap = {};
            if (scheduleType == _ScheduleCalendarType.classSchedule) {
              markerDates = sessionsState.sessions.map((s) => s.date).toSet();
              // Group sessions by date for counts & completed status
              for (final s in sessionsState.sessions) {
                sessionCounts[s.date] = (sessionCounts[s.date] ?? 0) + 1;
                if (s.status == 'Completed') {
                  allCompletedMap[s.date] ??= true;
                } else {
                  allCompletedMap[s.date] = false;
                }
              }
            } else {
              final allClients = sl<GetClientsUseCase>().execute();
              final dates = <String>{};
              for (final c in allClients) {
                for (final e in c.timeline) {
                  if (e.type != ClientTimelineEventType.payment) continue;
                  final dateKey = AppDateUtils.dateToStr(e.createdAt);
                  // Skip dates covered by an earlier Paid fully.
                  bool covered = false;
                  for (final s in c.timeline) {
                    if (s.type != ClientTimelineEventType.statusChanged) continue;
                    if (s.status?.trim() != 'Paid fully') continue;
                    final sKey = AppDateUtils.dateToStr(s.createdAt);
                    if (sKey.compareTo(dateKey) <= 0 && sKey != dateKey) {
                      covered = true;
                      break;
                    }
                  }
                  if (!covered) dates.add(dateKey);
                }
              }
              markerDates = dates;
            }

            return Center(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(28),
                  boxShadow: const [
                    BoxShadow(
                      color: Color(0x14000000),
                      blurRadius: 14,
                      offset: Offset(0, 8),
                    ),
                  ],
                ),
                child: SizedBox(
                  height: 74,
                  width: double.infinity,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
                    child: Builder(
                      builder: (context) {
                        final selected = calendarState.selectedDate;
                        final start = CalendarPageBody._startOfWeek(selected);
                        final days = List<DateTime>.generate(
                          7,
                          (i) => start.add(Duration(days: i)),
                        );

                        return Row(
                          children: days
                              .map(
                                (d) => Expanded(
                                  child: Padding(
                                    padding: const EdgeInsets.symmetric(horizontal: 3),
                                    child: _WeekDayChip(
                                      date: d,
                                      selected: _isSameDay(d, selected),
                                      hasSessions:
                                          markerDates.contains(AppDateUtils.dateToStr(d)),
                                      sessionCount: sessionCounts[AppDateUtils.dateToStr(d)] ?? 0,
                                      allCompleted: allCompletedMap[AppDateUtils.dateToStr(d)] ?? false,
                                      onTap: () => context
                                          .read<CalendarCubit>()
                                          .selectDate(d, explicit: true),
                                    ),
                                  ),
                                ),
                              )
                              .toList(),
                        );
                      },
                    ),
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }
}

class _WeekDayChip extends StatelessWidget {
  const _WeekDayChip({
    required this.date,
    required this.selected,
    required this.hasSessions,
    required this.onTap,
    this.sessionCount = 0,
    this.allCompleted = false,
  });

  final DateTime date;
  final bool selected;
  final bool hasSessions;
  final int sessionCount;
  final bool allCompleted;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    const dayNames = ['M', 'T', 'W', 'T', 'F', 'S', 'S'];
    final label = dayNames[date.weekday - 1];
    final chrome = AppChromeTheme.of(context);

    final bg = selected ? const Color(0xFFEDEDED) : const Color(0xFFF7F7F7);

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(18),
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(18),
        ),
        child: Center(
          child: FittedBox(
            fit: BoxFit.scaleDown,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  label,
                  maxLines: 1,
                  softWrap: false,
                  style: Theme.of(context).textTheme.labelSmall?.copyWith(
                        color: Colors.black54,
                        fontWeight: FontWeight.w700,
                        height: 1.0,
                      ),
                ),
                const SizedBox(height: 1),
                Text(
                  '${date.day}',
                  maxLines: 1,
                  softWrap: false,
                  style: Theme.of(context).textTheme.labelMedium?.copyWith(
                        color: Colors.black87,
                        fontWeight: FontWeight.w800,
                        height: 1.0,
                      ),
                ),
                if (hasSessions && sessionCount > 0) ...[
                  const SizedBox(height: 2),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                    decoration: BoxDecoration(
                      color: allCompleted
                          ? const Color(0xFF4CAF50)
                          : (selected
                              ? chrome.textColor
                              : chrome.accentBlue.withOpacity(0.85)),
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child: Text(
                      '$sessionCount',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 8,
                        fontWeight: FontWeight.w700,
                        height: 1.2,
                      ),
                    ),
                  ),
                ] else if (hasSessions) ...[
                  const SizedBox(height: 2),
                  DecoratedBox(
                    decoration: BoxDecoration(
                      color: selected
                          ? chrome.textColor
                          : chrome.accentBlue.withOpacity(0.85),
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child: const SizedBox(height: 6, width: 6),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _MonthlyTopContent extends StatelessWidget {
  const _MonthlyTopContent({
    super.key,
    required this.scheduleType,
  });

  final _ScheduleCalendarType scheduleType;

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<SessionsCubit, SessionsState>(
      builder: (context, sessionsState) {
        return BlocBuilder<CalendarCubit, CalendarState>(
          builder: (context, calendarState) {
            final Set<String> markerDates;
            final Map<String, int> sessionCounts = {};
            final Map<String, bool> allCompletedMap = {};
            if (scheduleType == _ScheduleCalendarType.classSchedule) {
              markerDates = sessionsState.sessions.map((s) => s.date).toSet();
              for (final s in sessionsState.sessions) {
                sessionCounts[s.date] = (sessionCounts[s.date] ?? 0) + 1;
                if (s.status == 'Completed') {
                  allCompletedMap[s.date] ??= true;
                } else {
                  allCompletedMap[s.date] = false;
                }
              }
            } else {
              final allClients = sl<GetClientsUseCase>().execute();
              final dates = <String>{};
              for (final c in allClients) {
                for (final e in c.timeline) {
                  if (e.type != ClientTimelineEventType.payment) continue;
                  final dateKey = AppDateUtils.dateToStr(e.createdAt);
                  bool covered = false;
                  for (final s in c.timeline) {
                    if (s.type != ClientTimelineEventType.statusChanged) continue;
                    if (s.status?.trim() != 'Paid fully') continue;
                    final sKey = AppDateUtils.dateToStr(s.createdAt);
                    if (sKey.compareTo(dateKey) <= 0 && sKey != dateKey) {
                      covered = true;
                      break;
                    }
                  }
                  if (!covered) dates.add(dateKey);
                }
              }
              markerDates = dates;
            }

            final selected = calendarState.selectedDate;
            final year = selected.year;
            final month = selected.month;
            final first = DateTime(year, month, 1);
            final leadingEmpty = first.weekday - 1; // Monday=0
            final daysInMonth = DateTime(year, month + 1, 0).day;
            final rows = ((leadingEmpty + daysInMonth) / 7).ceil().clamp(4, 6);
            final cellCount = rows * 7;
            final startDate = first.subtract(Duration(days: leadingEmpty));

            return Column(
              children: [
                const SizedBox(height: 4),
                const _WeekdayHeaderRow(),
                const SizedBox(height: 8),
                Expanded(
                  child: LayoutBuilder(
                    builder: (context, constraints) {
                      final spacing = (constraints.maxHeight / rows) < 36 ? 4.0 : 6.0;
                      final usableH = constraints.maxHeight - spacing * (rows - 1);
                      // Let the grid fill the available height to avoid empty space
                      // below the last week (common when a max cell height is used).
                      final computedCellH = usableH / rows;
                      final cellH = computedCellH < 20.0 ? 20.0 : computedCellH;

                      return GridView.builder(
                        primary: false,
                        padding: EdgeInsets.zero,
                        physics: const NeverScrollableScrollPhysics(),
                        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: 7,
                          mainAxisSpacing: spacing,
                          crossAxisSpacing: spacing,
                          mainAxisExtent: cellH,
                        ),
                        itemCount: cellCount,
                        itemBuilder: (context, index) {
                          final date = startDate.add(Duration(days: index));
                          final isInMonth =
                              date.month == month && date.year == year;
                          final isSelected =
                            isInMonth && _isSameDay(date, selected);
                          final isToday =
                            isInMonth && _isSameDay(date, DateTime.now());
                          final dateKey = AppDateUtils.dateToStr(date);
                          final hasSessions = isInMonth &&
                            markerDates.contains(dateKey);

                          return _MonthDayCell(
                            day: date.day,
                            selected: isSelected,
                            isToday: isToday,
                            inMonth: isInMonth,
                            hasSessions: hasSessions,
                            sessionCount: isInMonth ? (sessionCounts[dateKey] ?? 0) : 0,
                            allCompleted: isInMonth ? (allCompletedMap[dateKey] ?? false) : false,
                            onTap: isInMonth
                                ? () => context.read<CalendarCubit>().selectDate(date)
                                : () {},
                          );
                        },
                      );
                    },
                  ),
                ),
              ],
            );
          },
        );
      },
    );
  }
}

class _WeekdayHeaderRow extends StatelessWidget {
  const _WeekdayHeaderRow();

  @override
  Widget build(BuildContext context) {
    const labels = ['M', 'T', 'W', 'T', 'F', 'S', 'S'];
    return Row(
      children: labels
          .map(
            (t) => Expanded(
              child: Center(
                child: Text(
                  t,
                  style: Theme.of(context).textTheme.labelSmall?.copyWith(
                        color: Colors.black45,
                        fontWeight: FontWeight.w700,
                      ),
                ),
              ),
            ),
          )
          .toList(),
    );
  }
}

class _MonthDayCell extends StatelessWidget {
  const _MonthDayCell({
    required this.day,
    required this.selected,
    required this.isToday,
    required this.inMonth,
    required this.hasSessions,
    required this.onTap,
    this.sessionCount = 0,
    this.allCompleted = false,
  });

  final int day;
  final bool selected;
  final bool isToday;
  final bool inMonth;
  final bool hasSessions;
  final int sessionCount;
  final bool allCompleted;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final chrome = AppChromeTheme.of(context);
    final bg = selected
        ? const Color(0xFFE9E9E9)
        : (isToday ? const Color(0xFFF2F2F2) : const Color(0xFFF8F8F8));

    final cellBg = (inMonth && allCompleted && hasSessions)
        ? const Color(0xFFE8F5E9)
        : (inMonth ? bg : const Color(0xFFF8F8F8));

    return InkWell(
      onTap: inMonth ? onTap : null,
      borderRadius: BorderRadius.circular(16),
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: cellBg,
          borderRadius: BorderRadius.circular(16),
          border: (inMonth && allCompleted && hasSessions)
              ? Border.all(color: const Color(0xFF4CAF50), width: 1.5)
              : null,
        ),
        child: Center(
          child: FittedBox(
            fit: BoxFit.scaleDown,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (inMonth)
                  Text(
                    '$day',
                    style: Theme.of(context).textTheme.labelLarge?.copyWith(
                          color: (allCompleted && hasSessions)
                              ? const Color(0xFF2E7D32)
                              : Colors.black87,
                          fontWeight: FontWeight.w800,
                          height: 1.0,
                        ),
                  ),
                if (hasSessions && inMonth && sessionCount > 0) ...[
                  const SizedBox(height: 2),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                    decoration: BoxDecoration(
                      color: allCompleted
                          ? const Color(0xFF4CAF50)
                          : (selected
                              ? chrome.textColor.withOpacity(0.9)
                              : chrome.accentBlue.withOpacity(0.85)),
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child: Text(
                      '$sessionCount',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 8,
                        fontWeight: FontWeight.w700,
                        height: 1.2,
                      ),
                    ),
                  ),
                ] else if (hasSessions && inMonth) ...[
                  const SizedBox(height: 2),
                  DecoratedBox(
                    decoration: BoxDecoration(
                      color: selected
                          ? chrome.textColor.withOpacity(0.9)
                          : chrome.accentBlue.withOpacity(0.85),
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child: const SizedBox(height: 5, width: 5),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

bool _isSameDay(DateTime a, DateTime b) {
  return a.year == b.year && a.month == b.month && a.day == b.day;
}

class _CalendarBottomCard extends StatelessWidget {
  const _CalendarBottomCard({required this.scheduleType});

  final _ScheduleCalendarType scheduleType;

  @override
  Widget build(BuildContext context) {
    final chrome = AppChromeTheme.of(context);

    return DecoratedBox(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(CalendarPageBody._cardRadius),
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
        child: BlocBuilder<CalendarCubit, CalendarState>(
          builder: (context, calendarState) {
            final selectedDate = calendarState.selectedDate;
            final selectedDateStr = AppDateUtils.dateToStr(selectedDate);
            final isWeeklyAll = calendarState.viewMode == CalendarViewMode.weekly &&
                calendarState.weeklyDaySelected != true;

            // Compute the set of date strings to show.
            Set<String> visibleDateStrs;
            if (isWeeklyAll) {
              final weekday = selectedDate.weekday; // Monday=1
              final monday = selectedDate.subtract(Duration(days: weekday - 1));
              visibleDateStrs = {
                for (var i = 0; i < 7; i++)
                  AppDateUtils.dateToStr(monday.add(Duration(days: i))),
              };
            } else {
              visibleDateStrs = {selectedDateStr};
            }

            final clients = sl<GetClientsUseCase>().execute();
            final clientNames = {
              for (final c in clients) c.id: c.name,
            };
            final paymentItems = clients
                .expand(
                  (c) => c.timeline
                      .where((e) => e.type == ClientTimelineEventType.payment)
                      .map(
                        (e) => _PaymentScheduleItem(
                          clientId: c.id,
                          paymentEventId: e.id,
                          clientName: c.name,
                          amount: e.amount,
                          date: e.createdAt,
                          note: e.note,
                        ),
                      ),
                )
                .where((e) => visibleDateStrs.contains(AppDateUtils.dateToStr(e.date)))
                .toList(growable: false)
              ..sort((a, b) => a.date.compareTo(b.date));

            Future<void> openScheduleSheet() async {
              final sessionsCubit = context.read<SessionsCubit>();
              await showModalBottomSheet<void>(
                context: context,
                isScrollControlled: true,
                backgroundColor: Colors.transparent,
                builder: (ctx) {
                  return Padding(
                    padding: EdgeInsets.only(
                      bottom: MediaQuery.of(ctx).viewInsets.bottom,
                    ),
                    child: ClipRRect(
                      borderRadius:
                          const BorderRadius.vertical(top: Radius.circular(28)),
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          color: Theme.of(ctx).scaffoldBackgroundColor,
                        ),
                        child: BlocProvider.value(
                          value: sessionsCubit,
                          child: ScheduleSessionsSheet(initialDate: selectedDate),
                        ),
                      ),
                    ),
                  );
                },
              );
            }

            Future<void> openRescheduleSheet(ScheduleSession session) async {
              final sessionsCubit = context.read<SessionsCubit>();
              await showModalBottomSheet<void>(
                context: context,
                isScrollControlled: true,
                backgroundColor: Colors.transparent,
                builder: (ctx) {
                  return Padding(
                    padding: EdgeInsets.only(
                      bottom: MediaQuery.of(ctx).viewInsets.bottom,
                    ),
                    child: ClipRRect(
                      borderRadius:
                          const BorderRadius.vertical(top: Radius.circular(28)),
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          color: Theme.of(ctx).scaffoldBackgroundColor,
                        ),
                        child: BlocProvider.value(
                          value: sessionsCubit,
                          child: _RescheduleSessionSheet(session: session),
                        ),
                      ),
                    ),
                  );
                },
              );
            }

            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        scheduleType == _ScheduleCalendarType.classSchedule
                            ? 'Class Schedule'
                            : 'Payment Schedule',
                        style: Theme.of(context).textTheme.titleMedium?.copyWith(
                              color: chrome.textColor,
                              fontWeight: FontWeight.w900,
                            ),
                      ),
                    ),
                    if (scheduleType == _ScheduleCalendarType.classSchedule)
                      OutlinedButton.icon(
                        onPressed: openScheduleSheet,
                        icon: const Icon(Icons.add, size: 18),
                        label: const Text('Add'),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: chrome.textColor,
                          side: BorderSide(color: chrome.mutedColor.withOpacity(0.25)),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(999),
                          ),
                          padding: const EdgeInsets.symmetric(
                            horizontal: 14,
                            vertical: 10,
                          ),
                        ),
                      ),
                    if (scheduleType == _ScheduleCalendarType.paymentSchedule)
                      OutlinedButton.icon(
                        onPressed: () async {
                          final calendarCubit = context.read<CalendarCubit>();
                          final sessionsCubit = context.read<SessionsCubit>();
                          await showModalBottomSheet<void>(
                            context: context,
                            isScrollControlled: true,
                            backgroundColor: Colors.transparent,
                            builder: (ctx) {
                              return Padding(
                                padding: EdgeInsets.only(
                                  bottom: MediaQuery.of(ctx).viewInsets.bottom,
                                ),
                                child: BlocProvider.value(
                                  value: calendarCubit,
                                  child: BlocProvider.value(
                                    value: sessionsCubit,
                                    child: _AddPaymentSheet(selectedDate: selectedDate),
                                  ),
                                ),
                              );
                            },
                          );
                        },
                        icon: const Icon(Icons.add, size: 18),
                        label: const Text('Add'),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: chrome.textColor,
                          side: BorderSide(color: chrome.mutedColor.withOpacity(0.25)),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(999),
                          ),
                          padding: const EdgeInsets.symmetric(
                            horizontal: 14,
                            vertical: 10,
                          ),
                        ),
                      ),
                  ],
                ),
                // Add Payment Sheet for scheduling a payment for a client
                const SizedBox(height: 10),
                Expanded(
                  child: scheduleType == _ScheduleCalendarType.classSchedule
                      ? BlocBuilder<SessionsCubit, SessionsState>(
                          builder: (context, state) {
                            if (state.isLoading) {
                              return const Center(child: CircularProgressIndicator());
                            }
                            if (state.error != null) {
                              return Center(
                                child: Text(
                                  state.error!,
                                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                        color: Colors.red.shade700,
                                        fontWeight: FontWeight.w700,
                                      ),
                                ),
                              );
                            }

                            final sessions = state.sessions
                                .where((s) => visibleDateStrs.contains(s.date))
                                .toList()
                              ..sort((a, b) {
                                // Sort by date first, then by time.
                                final dateCompare = a.date.compareTo(b.date);
                                if (dateCompare != 0) return dateCompare;
                                final aStart = AppDateUtils.parseTimeRange(a.time)['start'] ?? 0;
                                final bStart = AppDateUtils.parseTimeRange(b.time)['start'] ?? 0;
                                return aStart.compareTo(bStart);
                              });

                            if (sessions.isEmpty) {
                              return Center(
                                child: Text(
                                  isWeeklyAll
                                      ? 'No sessions this week.'
                                      : 'No sessions for this day.',
                                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                        color: chrome.mutedColor,
                                        fontWeight: FontWeight.w700,
                                      ),
                                ),
                              );
                            }

                            return ClipRRect(
                              borderRadius: BorderRadius.circular(22),
                              child: DecoratedBox(
                                decoration: BoxDecoration(
                                  color: chrome.surfaceColor,
                                  border: Border.all(
                                    color: chrome.mutedColor.withOpacity(0.16),
                                  ),
                                ),
                                child: ListView.separated(
                                  itemCount: sessions.length,
                                  separatorBuilder: (_, __) => Divider(
                                    height: 1,
                                    thickness: 1,
                                    color: chrome.mutedColor.withOpacity(0.25),
                                  ),
                                  itemBuilder: (context, index) {
                                    final s = sessions[index];
                                    final derivedStatus = AppDateUtils.determineSessionStatus(
                                      s.status,
                                      s.date,
                                      s.time,
                                    );
                                    final name = clientNames[s.clientId] ?? 'Client';
                                    final dateLabel = isWeeklyAll ? '${AppDateUtils.displayDateStr(s.date)} • ' : '';
                                    return ListTile(
                                      dense: true,
                                      onTap: () => openRescheduleSheet(s),
                                      title: Text(
                                        name,
                                        style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                                              color: chrome.textColor,
                                              fontWeight: FontWeight.w800,
                                            ),
                                      ),
                                      subtitle: Text(
                                        '$dateLabel${s.time} • $derivedStatus',
                                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                              color: chrome.mutedColor,
                                              fontWeight: FontWeight.w600,
                                            ),
                                      ),
                                    );
                                  },
                                ),
                              ),
                            );
                          },
                        )
                      : _PaymentScheduleList(items: paymentItems, isWeeklyAll: isWeeklyAll),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}

class _PaymentScheduleItem {
  const _PaymentScheduleItem({
    required this.clientId,
    required this.paymentEventId,
    required this.clientName,
    required this.date,
    this.amount,
    this.note,
  });

  final String clientId;
  final String paymentEventId;
  final String clientName;
  final DateTime date;
  final double? amount;
  final String? note;
}

class _PaymentScheduleRow {
  const _PaymentScheduleRow({
    required this.item,
    required this.client,
    required this.status,
  });

  final _PaymentScheduleItem item;
  final Client client;
  final String status;
}

class _PaymentScheduleList extends StatelessWidget {
  const _PaymentScheduleList({required this.items, this.isWeeklyAll = false});

  final List<_PaymentScheduleItem> items;
  final bool isWeeklyAll;

  @override
  Widget build(BuildContext context) {
    final chrome = AppChromeTheme.of(context);
    final clients = sl<GetClientsUseCase>().execute();
    final clientMap = {for (final c in clients) c.id: c};

    String statusFor(Client client, DateTime date) {
      String status = 'Pending';
      try {
        final dateKey = AppDateUtils.dateToStr(date);
        final statusEvents = client.timeline.reversed
            .where((e) =>
                e.type == ClientTimelineEventType.statusChanged &&
                AppDateUtils.dateToStr(e.createdAt) == dateKey)
            .toList(growable: false);
        if (statusEvents.isNotEmpty) {
          final statusEvent = statusEvents.first;
          if (statusEvent.status != null && statusEvent.status!.trim().isNotEmpty) {
            status = statusEvent.status!;
          }
        }
      } catch (_) {}

      if (status != 'Pending' &&
          status != 'Paid' &&
          status != 'Paid fully' &&
          status != 'Will pay later') {
        status = 'Pending';
      }

      return status;
    }

    bool isCoveredByPaidFully(Client client, DateTime date) {
      final dateKey = AppDateUtils.dateToStr(date);
      for (final event in client.timeline.reversed) {
        if (event.type != ClientTimelineEventType.statusChanged) continue;
        if (event.status == null) continue;
        if (event.status!.trim() != 'Paid fully') continue;
        final key = AppDateUtils.dateToStr(event.createdAt);
        if (key == dateKey) {
          // Same-day "Paid fully" is the anchor; keep it visible.
          return false;
        }
        if (key.compareTo(dateKey) < 0) {
          // A prior Paid fully action covers this future installment.
          return true;
        }
      }
      return false;
    }

    final rows = <_PaymentScheduleRow>[];
    for (final item in items) {
      final client = clientMap[item.clientId];
      if (client == null) continue;
      final status = statusFor(client, item.date);
      if (isCoveredByPaidFully(client, item.date)) {
        continue;
      }
      rows.add(_PaymentScheduleRow(item: item, client: client, status: status));
    }

    if (rows.isEmpty) {
      return Center(
        child: Text(
          isWeeklyAll
              ? 'No payments this week.'
              : 'No payments for this day.',
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: chrome.mutedColor,
                fontWeight: FontWeight.w700,
              ),
        ),
      );
    }
    return ClipRRect(
      borderRadius: BorderRadius.circular(22),
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: chrome.surfaceColor,
          border: Border.all(
            color: chrome.mutedColor.withOpacity(0.16),
          ),
        ),
        child: ListView.separated(
          itemCount: rows.length,
          separatorBuilder: (_, __) => Divider(
            height: 1,
            thickness: 1,
            color: chrome.mutedColor.withOpacity(0.25),
          ),
          itemBuilder: (context, index) {
            final row = rows[index];
            final p = row.item;
            final client = row.client;
            final status = row.status;
            final amountLabel = p.amount == null ? 'No amount' : '₹${p.amount!.toStringAsFixed(0)}';

            Future<void> openReschedule() async {
              await showModalBottomSheet<void>(
                context: context,
                isScrollControlled: true,
                backgroundColor: Colors.transparent,
                builder: (ctx) {
                  return Padding(
                    padding: EdgeInsets.only(
                      bottom: MediaQuery.of(ctx).viewInsets.bottom,
                    ),
                    child: _ReschedulePaymentSheet(
                      clientId: p.clientId,
                      paymentEventId: p.paymentEventId,
                      currentDate: p.date,
                    ),
                  );
                },
              );

              if (!context.mounted) return;
              try {
                context.read<CalendarCubit>().refresh();
              } catch (_) {}
            }

            final isPaidOrPast = status == 'Paid' || status == 'Paid fully';

            return ListTile(
              dense: true,
              title: Text(
                p.clientName,
                style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                      color: chrome.textColor,
                      fontWeight: FontWeight.w800,
                    ),
              ),
              subtitle: Text(
                p.note != null && p.note!.trim().isNotEmpty
                    ? '$amountLabel • ${p.note!.trim()}'
                    : amountLabel,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: chrome.mutedColor,
                      fontWeight: FontWeight.w600,
                    ),
              ),
              trailing: DropdownButton<String>(
                value: status,
                items: const [
                  DropdownMenuItem(value: 'Pending', child: Text('Pending')),
                  DropdownMenuItem(value: 'Paid', child: Text('Paid')),
                  DropdownMenuItem(value: 'Paid fully', child: Text('Paid fully')),
                  DropdownMenuItem(value: 'Will pay later', child: Text('Will pay later')),
                ],
                onChanged: (v) {
                  if (v == null) return;

                  if (v == 'Pending') {
                    // If covered by "Paid fully", revert the whole batch.
                    bool coveredByPaidFully = false;
                    final dateKey = AppDateUtils.dateToStr(p.date);
                    for (final ev in client.timeline) {
                      if (ev.type != ClientTimelineEventType.statusChanged) continue;
                      if (ev.status?.trim() != 'Paid fully') continue;
                      final sKey = AppDateUtils.dateToStr(ev.createdAt);
                      if (sKey.compareTo(dateKey) <= 0) {
                        coveredByPaidFully = true;
                        break;
                      }
                    }

                    if (coveredByPaidFully) {
                      showDialog<bool>(
                        context: context,
                        builder: (ctx) => AlertDialog(
                          title: const Text('Revert Paid Fully?'),
                          content: const Text(
                            'This payment was marked via "Paid fully". '
                            'Reverting will reset ALL payments that were covered.\n\n'
                            'Continue?',
                          ),
                          actions: [
                            TextButton(
                              onPressed: () => Navigator.pop(ctx, false),
                              child: const Text('Cancel'),
                            ),
                            TextButton(
                              onPressed: () => Navigator.pop(ctx, true),
                              child: const Text('Revert'),
                            ),
                          ],
                        ),
                      ).then((confirmed) {
                        if (confirmed == true && context.mounted) {
                          context.read<ClientBloc>().add(
                                RevertClientPaidFully(entityId: client.id),
                              );
                          try { context.read<CalendarCubit>().refresh(); } catch (_) {}
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              duration: Duration(seconds: 1),
                              content: Text('Paid fully reverted'),
                            ),
                          );
                        }
                      });
                      return;
                    }

                    try {
                      context.read<ClientBloc>().add(ClearPaymentStatusForDate(
                        entityId: client.id,
                        date: p.date,
                      ));
                    } catch (_) {}

                    try {
                      context.read<CalendarCubit>().refresh();
                    } catch (_) {}
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        duration: const Duration(seconds: 1),
                        content: Text('Payment reset to Pending for ${AppDateUtils.displayDate(p.date)}'),
                      ),
                    );
                    return;
                  }

                  if (v == 'Will pay later') {
                    // If currently paid, clear the status first.
                    if (isPaidOrPast) {
                      bool coveredByPaidFully = false;
                      final dateKey = AppDateUtils.dateToStr(p.date);
                      for (final ev in client.timeline) {
                        if (ev.type != ClientTimelineEventType.statusChanged) continue;
                        if (ev.status?.trim() != 'Paid fully') continue;
                        final sKey = AppDateUtils.dateToStr(ev.createdAt);
                        if (sKey.compareTo(dateKey) <= 0) {
                          coveredByPaidFully = true;
                          break;
                        }
                      }
                      if (coveredByPaidFully) {
                        context.read<ClientBloc>().add(
                              RevertClientPaidFully(entityId: client.id),
                            );
                      } else {
                        context.read<ClientBloc>().add(ClearPaymentStatusForDate(
                          entityId: client.id,
                          date: p.date,
                        ));
                      }
                    }
                    openReschedule();
                    return;
                  }

                  if (v == 'Paid') {
                    // Do not add another payment entry; the scheduled payment already exists.
                    // Only mark this scheduled payment as paid.
                    context.read<ClientBloc>().add(UpdateClientStatus(
                      entityId: client.id,
                      status: 'Paid',
                      createdAt: p.date,
                    ));
                    try {
                      context.read<CalendarCubit>().refresh();
                    } catch (_) {}
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        duration: const Duration(seconds: 1),
                        content: Text('Payment marked Paid for ${AppDateUtils.displayDate(p.date)}'),
                      ),
                    );
                    return;
                  }

                  if (v == 'Paid fully') {
                    // Mark this and remaining scheduled payments as paid.
                    context.read<ClientBloc>().add(MarkClientPaidFully(
                      entityId: client.id,
                      fromDate: p.date,
                    ));
                    try {
                      context.read<CalendarCubit>().refresh();
                    } catch (_) {}
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        duration: const Duration(seconds: 1),
                        content: Text('Marked Paid fully from ${AppDateUtils.displayDate(p.date)}'),
                      ),
                    );
                    return;
                  }
                },
              ),
            );
          },
        ),
      ),
    );
  }
}

class _RescheduleSessionSheet extends StatefulWidget {
  const _RescheduleSessionSheet({required this.session});

  final ScheduleSession session;

  @override
  State<_RescheduleSessionSheet> createState() => _RescheduleSessionSheetState();
}

class _ReschedulePaymentSheet extends StatefulWidget {
  const _ReschedulePaymentSheet({
    required this.clientId,
    required this.paymentEventId,
    required this.currentDate,
  });

  final String clientId;
  final String paymentEventId;
  final DateTime currentDate;

  @override
  State<_ReschedulePaymentSheet> createState() => _ReschedulePaymentSheetState();
}

class _ReschedulePaymentSheetState extends State<_ReschedulePaymentSheet> {
  late DateTime _newDate;

  @override
  void initState() {
    super.initState();
    _newDate = DateTime(widget.currentDate.year, widget.currentDate.month, widget.currentDate.day);
  }

  DateTime _normalizeDay(DateTime d) => DateTime(d.year, d.month, d.day);

  Future<bool> _confirmMerge({required String message}) async {
    final res = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Warning'),
          content: Text(message),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(context).pop(true),
              child: const Text('Merge'),
            ),
          ],
        );
      },
    );
    return res ?? false;
  }

  Future<void> _save() async {
    final clients = sl<GetClientsUseCase>().execute();
    final client = clients.firstWhere((c) => c.id == widget.clientId);
    final timeline = client.timeline;

    // Find the exact payment object by id AND date (safe even with legacy duplicate IDs).
    final oldKey = AppDateUtils.dateToStr(_normalizeDay(widget.currentDate));
    ClientTimelineEvent? old;
    for (final e in timeline) {
      if (e.type != ClientTimelineEventType.payment) continue;
      if (e.id != widget.paymentEventId) continue;
      if (AppDateUtils.dateToStr(_normalizeDay(e.createdAt)) == oldKey) {
        old = e;
        break;
      }
    }
    // Fallback: match by id only (for newly-generated unique IDs).
    old ??= timeline.firstWhere(
      (e) => e.type == ClientTimelineEventType.payment && e.id == widget.paymentEventId,
    );

    final targetDay = _normalizeDay(_newDate);
    final targetKey = AppDateUtils.dateToStr(targetDay);

    if (AppDateUtils.dateToStr(_normalizeDay(old.createdAt)) == targetKey) {
      if (mounted) Navigator.of(context).pop();
      return;
    }

    // Look for an existing payment on the target date for the SAME client.
    // Use `identical` to skip the exact object we're rescheduling.
    ClientTimelineEvent? existing;
    for (final e in timeline) {
      if (identical(e, old)) continue;
      if (e.type != ClientTimelineEventType.payment) continue;
      if (AppDateUtils.dateToStr(_normalizeDay(e.createdAt)) == targetKey) {
        existing = e;
        break;
      }
    }

    if (existing != null) {
      // --- Merge path: target date already has a payment for this client ---
      final targetPayment = existing;
      final existingAmount = targetPayment.amount ?? 0;
      final oldAmount = old.amount ?? 0;
      final merged = existingAmount + oldAmount;
      final message =
          '${client.name} already has ₹${existingAmount.toStringAsFixed(0)} scheduled on $targetKey.\n'
          'Merge with this ₹${oldAmount.toStringAsFixed(0)} payment for a total of ₹${merged.toStringAsFixed(0)}?';

      final ok = await _confirmMerge(message: message);
      if (!mounted) return;
      if (!ok) return;

      String? mergedNote;
      if (targetPayment.note != null && targetPayment.note!.trim().isNotEmpty) {
        mergedNote = targetPayment.note!.trim();
      } else if (old.note != null && old.note!.trim().isNotEmpty) {
        mergedNote = old.note!.trim();
      }

      // Dispatch merge through the bloc pipeline.
      context.read<ClientBloc>().add(MergeClientPayments(
        entityId: widget.clientId,
        sourcePaymentId: old.id,
        sourceDate: _normalizeDay(old.createdAt),
        targetPaymentId: targetPayment.id,
        targetDate: targetDay,
        mergedAmount: merged,
        mergedNote: mergedNote,
      ));
      if (mounted) Navigator.of(context).pop();
      return;
    }

    // --- Simple move path: no existing payment on target date ---
    context.read<ClientBloc>().add(RescheduleClientPayment(
      entityId: widget.clientId,
      paymentId: old.id,
      oldDate: _normalizeDay(old.createdAt),
      newDate: targetDay,
    ));
    if (mounted) Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final chrome = AppChromeTheme.of(context);
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 20),
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(24),
          ),
          child: Padding(
            padding: const EdgeInsets.all(18.0),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        'Reschedule Payment',
                        style: Theme.of(context).textTheme.titleMedium?.copyWith(
                              color: chrome.textColor,
                              fontWeight: FontWeight.w800,
                            ),
                      ),
                    ),
                    IconButton(
                      onPressed: () => Navigator.of(context).pop(),
                      icon: Icon(Icons.close, color: chrome.mutedColor),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton(
                    style: OutlinedButton.styleFrom(
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                      side: BorderSide(color: chrome.mutedColor.withOpacity(0.25)),
                      padding: const EdgeInsets.symmetric(vertical: 14),
                    ),
                    onPressed: () async {
                      final now = DateTime.now();
                      final today = DateTime(now.year, now.month, now.day);
                      final picked = await showDatePicker(
                        context: context,
                        initialDate: _newDate.isBefore(today) ? today : _newDate,
                        firstDate: today,
                        lastDate: DateTime(now.year + 5, 12, 31),
                      );
                      if (picked == null) return;
                      setState(() => _newDate = _normalizeDay(picked));
                    },
                    child: Text(AppDateUtils.displayDate(_newDate)),
                  ),
                ),
                const SizedBox(height: 14),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                      backgroundColor: chrome.surfaceColor,
                      foregroundColor: chrome.textColor,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                    ),
                    onPressed: _save,
                    child: const Text('Save'),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _RescheduleSessionSheetState extends State<_RescheduleSessionSheet> {
  late DateTime _date;
  late int _startTimeMinutes;
  SessionDuration _duration = SessionDuration.oneHour;

  SessionDuration _durationFromMinutes(int minutes) {
    switch (minutes) {
      case 30:
        return SessionDuration.halfHour;
      case 60:
        return SessionDuration.oneHour;
      case 120:
        return SessionDuration.twoHours;
      case 180:
        return SessionDuration.threeHours;
      case 480:
        return SessionDuration.wholeDay;
      default:
        return SessionDuration.oneHour;
    }
  }

  int _durationMinutesForSession() {
    final d = _duration;
    return (d.hours * 60).round();
  }

  String _selectedTimeRangeLabel() {
    return AppDateUtils.formatTimeRangeFromStartAndDuration(
      startLabel: AppDateUtils.formatTimeLabelFromMinutes(_startTimeMinutes),
      durationMinutes: _durationMinutesForSession(),
    );
  }

  List<ScheduleSession> _findClashes(List<ScheduleSession> existing) {
    final selectedDate = AppDateUtils.dateToStr(_date);
    final selectedRange = AppDateUtils.parseTimeRange(_selectedTimeRangeLabel());
    final selectedStart = selectedRange['start'] ?? 0;
    final selectedEnd = selectedRange['end'] ?? selectedStart;

    return existing.where((s) {
      if (s.id == widget.session.id) return false;
      if (s.date != selectedDate) return false;

      final exRange = AppDateUtils.parseTimeRange(s.time);
      final exStart = exRange['start'] ?? 0;
      final exEnd = exRange['end'] ?? exStart;

      return (selectedStart < exEnd) && (selectedEnd > exStart);
    }).toList(growable: false);
  }

  @override
  void initState() {
    super.initState();
    _date = AppDateUtils.parseSessionDate(widget.session.date);

    final parsed = AppDateUtils.parseTimeRange(widget.session.time);
    final startMinutes = parsed['start'] ?? 0;
    _startTimeMinutes = startMinutes;

    if (widget.session.duration != null) {
      _duration = widget.session.duration!;
    } else {
      final endMinutes = parsed['end'] ?? startMinutes;
      final diff = endMinutes - startMinutes;
      _duration = _durationFromMinutes(diff > 0 ? diff : 60);
    }
  }

  Future<void> _pickDate() async {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final picked = await showDatePicker(
      context: context,
      initialDate: _date.isBefore(today) ? today : _date,
      firstDate: today,
      lastDate: DateTime(now.year + 5, 12, 31),
    );
    if (picked == null) return;
    setState(() => _date = picked);
  }

  Future<void> _save() async {
    final cubit = context.read<SessionsCubit>();
    final clashes = _findClashes(cubit.state.sessions);
    if (clashes.isNotEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          duration: Duration(seconds: 1),
          content: Text('Selected slot clashes with existing sessions.'),
        ),
      );
      return;
    }

    final durationMinutes = _durationMinutesForSession();
    final updated = widget.session.copyWith(
      date: AppDateUtils.dateToStr(_date),
      time: AppDateUtils.formatTimeRangeFromStartAndDuration(
        startLabel: AppDateUtils.formatTimeLabelFromMinutes(_startTimeMinutes),
        durationMinutes: durationMinutes,
      ),
      duration: _duration,
    );
    await cubit.updateSession(updated);
    if (!mounted) return;
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final chrome = AppChromeTheme.of(context);
    final durationMinutes = _durationMinutesForSession();
    final startLabel = AppDateUtils.formatTimeLabelFromMinutes(_startTimeMinutes);
    final timeRangeLabel = AppDateUtils.formatTimeRangeFromStartAndDuration(
      startLabel: startLabel,
      durationMinutes: durationMinutes,
    );

    Future<void> pickStartTime() async {
      final picked = await showTimePicker(
        context: context,
        initialTime: TimeOfDay(
          hour: (_startTimeMinutes ~/ 60) % 24,
          minute: _startTimeMinutes % 60,
        ),
      );
      if (picked == null) return;
      setState(() => _startTimeMinutes = picked.hour * 60 + picked.minute);
    }

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 20),
        child: BlocBuilder<SessionsCubit, SessionsState>(
          builder: (context, state) {
            final clashes = _findClashes(state.sessions);
            final hasClash = clashes.isNotEmpty;

            return Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        'Reschedule class',
                        style: Theme.of(context).textTheme.titleMedium?.copyWith(
                              color: chrome.textColor,
                              fontWeight: FontWeight.w800,
                            ),
                      ),
                    ),
                    IconButton(
                      onPressed: () => Navigator.of(context).pop(),
                      icon: Icon(Icons.close, color: chrome.mutedColor),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                OutlinedButton.icon(
                  onPressed: _pickDate,
                  icon: const Icon(Icons.calendar_month_outlined, size: 18),
                  label: Text('Date: ${AppDateUtils.displayDate(_date)}'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: chrome.textColor,
                    side: BorderSide(color: chrome.mutedColor.withOpacity(0.35)),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                  ),
                ),
                const SizedBox(height: 12),
                Material(
                  color: Colors.transparent,
                  child: InkWell(
                    onTap: pickStartTime,
                    borderRadius: BorderRadius.circular(14),
                    child: InputDecorator(
                      decoration: InputDecoration(
                        labelText: 'Time',
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                      ),
                      child: Row(
                        children: [
                          Expanded(
                            child: Text(
                              timeRangeLabel,
                              style: Theme.of(context).textTheme.bodyLarge,
                            ),
                          ),
                          Icon(Icons.access_time, color: chrome.mutedColor),
                        ],
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<SessionDuration>(
                  value: _duration,
                  items: SessionDuration.values
                      .map(
                        (d) => DropdownMenuItem<SessionDuration>(
                          value: d,
                          child: Text(d.displayName),
                        ),
                      )
                      .toList(),
                  onChanged: (v) {
                    if (v == null) return;
                    setState(() => _duration = v);
                  },
                  decoration: InputDecoration(
                    labelText: 'Duration',
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                ),
                const SizedBox(height: 10),
                Text(
                  hasClash
                      ? 'Clash found with ${clashes.length} session(s): ${clashes.take(2).map((s) => s.time).join(', ')}${clashes.length > 2 ? '...' : ''}'
                      : 'No clash for selected time.',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: hasClash ? Colors.red.shade700 : Colors.green.shade700,
                        fontWeight: FontWeight.w700,
                      ),
                ),
                const SizedBox(height: 14),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: hasClash ? null : _save,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.black,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(999),
                      ),
                      padding: const EdgeInsets.symmetric(vertical: 14),
                    ),
                    child: const Text('Save'),
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}

class _AddPaymentSheet extends StatefulWidget {
  final DateTime selectedDate;
  const _AddPaymentSheet({required this.selectedDate});

  @override
  State<_AddPaymentSheet> createState() => _AddPaymentSheetState();
}

class _AddPaymentSheetState extends State<_AddPaymentSheet> {
  final _formKey = GlobalKey<FormState>();

  String? _clientId;
  final _fullAmountController = TextEditingController();
  final _frequentAmountController = TextEditingController();
  late final FocusNode _fullAmountFocus;
  late final FocusNode _frequentAmountFocus;
  String _frequency = 'Monthly';
  int _customDays = 1;
  int _weeklyDay = DateTime.monday;
  int _monthlyDate = 1;
  int _times = 8;
  late final List<Client> clients;

  List<DateTime> _draftDates = const [];
  Set<String> _draftClashKeys = const <String>{};
  double _draftAmount = 0;
  String _draftNote = '';

  void _clearDraft() {
    _draftDates = const [];
    _draftClashKeys = const <String>{};
  }

  bool get _hasTotalText => _fullAmountController.text.trim().isNotEmpty;
  bool get _hasFrequentText => _frequentAmountController.text.trim().isNotEmpty;

  @override
  void initState() {
    super.initState();
    clients = sl<GetClientsUseCase>().execute();
    if (clients.isNotEmpty) {
      _clientId = clients.first.id;
    }
    _weeklyDay = widget.selectedDate.weekday;
    _monthlyDate = widget.selectedDate.day;

    _fullAmountFocus = FocusNode();
    _frequentAmountFocus = FocusNode();

    void onAmountTextChanged() {
      if (!mounted) return;
      // Rebuild to update enable/disable + warning overlays dynamically.
      if (_draftDates.isNotEmpty) {
        setState(() => _clearDraft());
      } else {
        setState(() {});
      }
    }

    _fullAmountController.addListener(onAmountTextChanged);
    _frequentAmountController.addListener(onAmountTextChanged);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Ensure initial client selection prefers a client that has sessions scheduled
    try {
      final sessions = context.read<SessionsCubit>().state.sessions;
      final clientsWithSessions = clients.where((c) =>
        sessions.any((s) => s.clientId == c.id)
      ).toList(growable: false);
      if (clientsWithSessions.isNotEmpty) {
        if (_clientId == null || !clientsWithSessions.any((c) => c.id == _clientId)) {
          _clientId = clientsWithSessions.first.id;
        }
      } else {
        // Fall back to first client so payments can still be scheduled.
        if (clients.isNotEmpty) {
          _clientId ??= clients.first.id;
        }
      }
    } catch (_) {
      // ignore: keep existing behavior if sessions cubit isn't available
    }
  }

  @override
  void dispose() {
    _fullAmountController.dispose();
    _frequentAmountController.dispose();
    _fullAmountFocus.dispose();
    _frequentAmountFocus.dispose();
    super.dispose();
  }

  DateTime _normalizeDay(DateTime d) => DateTime(d.year, d.month, d.day);

  int _daysInMonth(int year, int month) {
    return DateTime(year, month + 1, 0).day;
  }

  DateTime _clampToMonthDay(int year, int month, int day) {
    final dim = _daysInMonth(year, month);
    return DateTime(year, month, day.clamp(1, dim));
  }

  Set<String> _existingPaymentKeysForClient(String clientId) {
    final selectedClient = clients.firstWhere((c) => c.id == clientId);
    return selectedClient.timeline
        .where((e) => e.type == ClientTimelineEventType.payment)
        .map((e) => AppDateUtils.dateToStr(_normalizeDay(e.createdAt)))
        .toSet();
  }

  DateTime _firstDateForFrequency({
    required DateTime start,
    required String frequency,
    required int weeklyDay,
    required int monthlyDate,
  }) {
    final startDay = _normalizeDay(start);

    if (frequency == 'Weekly') {
      var d = startDay;
      while (d.weekday != weeklyDay) {
        d = d.add(const Duration(days: 1));
      }
      return d;
    }

    if (frequency == 'Monthly') {
      var d = _clampToMonthDay(startDay.year, startDay.month, monthlyDate);
      if (d.isBefore(startDay)) {
        d = _clampToMonthDay(startDay.year, startDay.month + 1, monthlyDate);
      }
      return _normalizeDay(d);
    }

    // Daily + Custom start from selected date.
    return startDay;
  }

  DateTime _nextDateForFrequency({
    required DateTime current,
    required String frequency,
    required int customDays,
    required int monthlyDate,
  }) {
    switch (frequency) {
      case 'Daily':
        return current.add(const Duration(days: 1));
      case 'Weekly':
        return current.add(const Duration(days: 7));
      case 'Monthly':
        return _clampToMonthDay(current.year, current.month + 1, monthlyDate);
      case 'Custom':
        final step = customDays <= 0 ? 1 : customDays;
        return current.add(Duration(days: step));
      default:
        return current.add(const Duration(days: 1));
    }
  }

  List<DateTime> _generateNonCollidingDates({
    required DateTime start,
    required String frequency,
    required int weeklyDay,
    required int monthlyDate,
    required int customDays,
    required int count,
    required Set<String> existingPaymentKeys,
  }) {
    final result = <DateTime>[];
    final seen = <String>{};

    var d = _firstDateForFrequency(
      start: start,
      frequency: frequency,
      weeklyDay: weeklyDay,
      monthlyDate: monthlyDate,
    );

    var guard = 0;
    while (result.length < count && guard < (count * 40).clamp(40, 2000)) {
      guard++;
      final key = AppDateUtils.dateToStr(_normalizeDay(d));
      if (!existingPaymentKeys.contains(key) && seen.add(key)) {
        result.add(_normalizeDay(d));
      }
      d = _nextDateForFrequency(
        current: d,
        frequency: frequency,
        customDays: customDays,
        monthlyDate: monthlyDate,
      );
    }

    return result;
  }

  Future<bool> _confirmOverride({required String message}) async {
    final res = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Warning'),
          content: Text(message),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(context).pop(true),
              child: const Text('Override'),
            ),
          ],
        );
      },
    );
    return res ?? false;
  }

  bool _generateDraft() {
    if (!_formKey.currentState!.validate()) return false;
    final clientId = _clientId;
    if (clientId == null) return false;

    final fullAmount = double.tryParse(_fullAmountController.text.trim());
    final frequentAmount = double.tryParse(_frequentAmountController.text.trim());
    final hasFull = fullAmount != null && fullAmount > 0;
    final hasFrequent = frequentAmount != null && frequentAmount > 0;

    if (!hasFull && !hasFrequent) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          duration: Duration(seconds: 1),
          content: Text('Enter total amount or amount per payment.'),
        ),
      );
      return false;
    }

    if (hasFull && hasFrequent) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          duration: Duration(seconds: 1),
          content: Text('Enter only one: total amount OR amount per payment.'),
        ),
      );
      return false;
    }

    String note = _frequency;
    if (_frequency == 'Custom') {
      note = 'Every $_customDays days';
    }

    final existingPaymentKeys = _existingPaymentKeysForClient(clientId);

    final isTotalAmount = hasFull;
    final int desiredCount = _times;
    final double amountPerPayment;
    if (isTotalAmount) {
      amountPerPayment = fullAmount / desiredCount;
    } else {
      amountPerPayment = frequentAmount!;
    }
    final start = widget.selectedDate;

    final generated = _generateNonCollidingDates(
      start: start,
      frequency: _frequency,
      weeklyDay: _weeklyDay,
      monthlyDate: _monthlyDate,
      customDays: _customDays,
      count: desiredCount,
      existingPaymentKeys: existingPaymentKeys,
    );

    if (generated.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          duration: Duration(seconds: 1),
          content: Text('Unable to generate any clash-free payment dates.'),
        ),
      );
      return false;
    }

    const clashKeys = <String>{};

    setState(() {
      _draftDates = generated;
      _draftClashKeys = clashKeys;
      _draftAmount = amountPerPayment;
      _draftNote = isTotalAmount ? 'Split total • $note' : note;
    });

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        duration: const Duration(seconds: 1),
        content: Text(
          'Generated ${generated.length}/${desiredCount} payment(s) (no clashes).',
        ),
      ),
    );
    return true;
  }

  void _saveDraft() {
    final clientId = _clientId;
    if (clientId == null) return;
    if (_draftDates.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          duration: Duration(seconds: 1),
          content: Text('Press Generate first.'),
        ),
      );
      return;
    }

    if (_draftClashKeys.isNotEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          duration: Duration(seconds: 1),
          content: Text('Resolve clashes and Generate again before saving.'),
        ),
      );
      return;
    }

    for (final d in _draftDates) {
      context.read<ClientBloc>().add(AddPaymentToClient(
        entityId: clientId,
        amount: _draftAmount,
        note: _draftNote,
        scheduledAt: d,
      ));
    }

    try {
      context.read<CalendarCubit>().refresh();
    } catch (_) {}

    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final chrome = AppChromeTheme.of(context);
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 20),
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(24),
          ),
          child: Padding(
            padding: const EdgeInsets.all(18.0),
            child: Form(
              key: _formKey,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        'Schedule Payment',
                        style: Theme.of(context).textTheme.titleMedium?.copyWith(
                              color: chrome.textColor,
                              fontWeight: FontWeight.w800,
                            ),
                      ),
                    ),
                    IconButton(
                      onPressed: () => Navigator.of(context).pop(),
                      icon: Icon(Icons.close, color: chrome.mutedColor),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Builder(
                  builder: (ctx) {
                    final availableClients = clients;

                    final selectedClient = availableClients.cast<Client?>().firstWhere(
                          (c) => c?.id == _clientId,
                          orElse: () => null,
                        );

                    return _PaymentSearchableSelectField<String>(
                      label: 'Client',
                      value: _clientId,
                      displayValue: selectedClient?.name ?? '',
                      options: availableClients
                          .map((c) => _PaymentOptionItem(value: c.id, label: c.name))
                          .toList(growable: false),
                      onChanged: (v) => setState(() {
                        _clientId = v;
                        _clearDraft();
                      }),
                    );
                  },
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  value: _frequency,
                  decoration: InputDecoration(
                    labelText: 'Frequency',
                    filled: true,
                    fillColor: chrome.surfaceColor,
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(16)),
                  ),
                  items: const [
                    DropdownMenuItem(value: 'Daily', child: Text('Daily')),
                    DropdownMenuItem(value: 'Weekly', child: Text('Weekly')),
                    DropdownMenuItem(value: 'Monthly', child: Text('Monthly')),
                    DropdownMenuItem(value: 'Custom', child: Text('Custom')),
                  ],
                  onChanged: (v) {
                    setState(() {
                      _frequency = v ?? 'Monthly';
                      _clearDraft();
                    });
                  },
                ),
                if (_frequency == 'Custom') ...[
                  const SizedBox(height: 12),
                  TextFormField(
                    initialValue: _customDays.toString(),
                    keyboardType: TextInputType.number,
                    decoration: InputDecoration(
                      labelText: 'Repeat every (days)',
                      filled: true,
                      fillColor: chrome.surfaceColor,
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(16)),
                    ),
                    onChanged: (v) {
                      final val = int.tryParse(v);
                      if (val != null && val > 0) {
                        setState(() {
                          _customDays = val;
                          _clearDraft();
                        });
                      }
                    },
                  ),
                ],
                const SizedBox(height: 12),
                if (_frequency == 'Weekly')
                  DropdownButtonFormField<int>(
                    value: _weeklyDay,
                    decoration: InputDecoration(
                      labelText: 'Day of the week',
                      filled: true,
                      fillColor: chrome.surfaceColor,
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(16)),
                    ),
                    items: const [
                      DropdownMenuItem(value: DateTime.monday, child: Text('Monday')),
                      DropdownMenuItem(value: DateTime.tuesday, child: Text('Tuesday')),
                      DropdownMenuItem(value: DateTime.wednesday, child: Text('Wednesday')),
                      DropdownMenuItem(value: DateTime.thursday, child: Text('Thursday')),
                      DropdownMenuItem(value: DateTime.friday, child: Text('Friday')),
                      DropdownMenuItem(value: DateTime.saturday, child: Text('Saturday')),
                      DropdownMenuItem(value: DateTime.sunday, child: Text('Sunday')),
                    ],
                    onChanged: (v) {
                      if (v == null) return;
                      setState(() {
                        _weeklyDay = v;
                        _clearDraft();
                      });
                    },
                  )
                else if (_frequency == 'Monthly')
                  _PaymentNumberField(
                    label: 'Day of the month',
                    value: _monthlyDate,
                    min: 1,
                    max: 31,
                    onChanged: (v) => setState(() {
                      _monthlyDate = v;
                      _clearDraft();
                    }),
                  )
                else
                  const SizedBox.shrink(),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: Stack(
                        children: [
                          TextFormField(
                            controller: _fullAmountController,
                            focusNode: _fullAmountFocus,
                            enabled: !_hasFrequentText,
                            keyboardType: TextInputType.number,
                            inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[0-9.]'))],
                            decoration: InputDecoration(
                              labelText: 'Total amount',
                              filled: true,
                              fillColor: chrome.surfaceColor,
                              border: OutlineInputBorder(borderRadius: BorderRadius.circular(16)),
                            ),
                          ),
                          if (_hasFrequentText)
                            Positioned.fill(
                              child: Material(
                                color: Colors.transparent,
                                child: InkWell(
                                  borderRadius: BorderRadius.circular(16),
                                  onTap: () async {
                                    final ok = await _confirmOverride(
                                      message: 'Amount per payment is already filled. Override it? This will clear Amount per payment.',
                                    );
                                    if (!ok) return;
                                    setState(() {
                                      _frequentAmountController.clear();
                                      _clearDraft();
                                    });
                                    _fullAmountFocus.requestFocus();
                                  },
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Stack(
                        children: [
                          TextFormField(
                            controller: _frequentAmountController,
                            focusNode: _frequentAmountFocus,
                            enabled: !_hasTotalText,
                            keyboardType: TextInputType.number,
                            inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[0-9.]'))],
                            decoration: InputDecoration(
                              labelText: 'Amount per payment',
                              filled: true,
                              fillColor: chrome.surfaceColor,
                              border: OutlineInputBorder(borderRadius: BorderRadius.circular(16)),
                            ),
                          ),
                          if (_hasTotalText)
                            Positioned.fill(
                              child: Material(
                                color: Colors.transparent,
                                child: InkWell(
                                  borderRadius: BorderRadius.circular(16),
                                  onTap: () async {
                                    final ok = await _confirmOverride(
                                      message: 'Total amount is already filled. Override it? This will clear Total amount.',
                                    );
                                    if (!ok) return;
                                    setState(() {
                                      _fullAmountController.clear();
                                      _clearDraft();
                                    });
                                    _frequentAmountFocus.requestFocus();
                                  },
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                _PaymentNumberField(
                  label: 'Number of payments',
                  value: _times,
                  min: 1,
                  max: 60,
                  enabled: _hasTotalText || _hasFrequentText,
                  onChanged: (v) => setState(() {
                    _times = v;
                    _clearDraft();
                  }),
                ),
                if (_draftDates.isNotEmpty) ...[
                  const SizedBox(height: 14),
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          _draftClashKeys.isEmpty
                              ? 'Generated payments'
                              : 'Generated payments (${_draftClashKeys.length} clash)',
                          style: Theme.of(context).textTheme.titleSmall?.copyWith(
                                color: chrome.textColor,
                                fontWeight: FontWeight.w800,
                              ),
                        ),
                      ),
                      if (_draftClashKeys.isNotEmpty)
                        Text(
                          'Resolve clashes to save',
                          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                color: Colors.red.shade700,
                                fontWeight: FontWeight.w700,
                              ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  DecoratedBox(
                    decoration: BoxDecoration(
                      color: chrome.surfaceColor,
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(12.0),
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(maxHeight: 180),
                        child: ListView.separated(
                          shrinkWrap: true,
                          itemCount: _draftDates.length,
                          separatorBuilder: (_, __) => const Divider(height: 16),
                          itemBuilder: (context, i) {
                            final d = _draftDates[i];
                            final key = AppDateUtils.dateToStr(_normalizeDay(d));
                            final isClash = _draftClashKeys.contains(key);
                            return Row(
                              children: [
                                Expanded(
                                  child: Text(
                                    key,
                                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                          color: isClash ? Colors.red.shade700 : chrome.textColor,
                                          fontWeight: FontWeight.w700,
                                        ),
                                  ),
                                ),
                                Text(
                                  '₹${_draftAmount.toStringAsFixed(0)}',
                                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                        color: isClash ? Colors.red.shade700 : chrome.textColor,
                                        fontWeight: FontWeight.w700,
                                      ),
                                ),
                              ],
                            );
                          },
                        ),
                      ),
                    ),
                  ),
                ],
                const SizedBox(height: 14),
                Row(
                  children: [
                    Expanded(
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                          backgroundColor: chrome.surfaceColor,
                          foregroundColor: chrome.textColor,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                        ),
                        onPressed: _generateDraft,
                        child: const Text('Generate'),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                          backgroundColor: chrome.surfaceColor,
                          foregroundColor: chrome.textColor,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                        ),
                        onPressed:
                            (_draftDates.isEmpty || _draftClashKeys.isNotEmpty) ? null : _saveDraft,
                        child: const Text('Save'),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    ),
  );
  }
}

class _PaymentOptionItem<T> {
  const _PaymentOptionItem({required this.value, required this.label});

  final T value;
  final String label;
}

class _PaymentSearchableSelectField<T> extends StatefulWidget {
  const _PaymentSearchableSelectField({
    required this.label,
    required this.value,
    required this.displayValue,
    required this.options,
    required this.onChanged,
    this.validator,
    this.enabled = true,
  });

  final String label;
  final T? value;
  final String displayValue;
  final List<_PaymentOptionItem<T>> options;
  final ValueChanged<T?> onChanged;
  final String? Function(T?)? validator;
  final bool enabled;

  @override
  State<_PaymentSearchableSelectField<T>> createState() => _PaymentSearchableSelectFieldState<T>();
}

class _PaymentSearchableSelectFieldState<T> extends State<_PaymentSearchableSelectField<T>> {
  bool _expanded = false;
  late final TextEditingController _searchController;
  late final FocusNode _searchFocusNode;

  @override
  void initState() {
    super.initState();
    _searchController = TextEditingController();
    _searchFocusNode = FocusNode();
    _searchFocusNode.addListener(() {
      if (!_searchFocusNode.hasFocus && _expanded) {
        // Delay collapse so an in-progress tap on a list item can register.
        Future.delayed(const Duration(milliseconds: 120), () {
          if (!mounted || !_expanded) return;
          setState(() {
            _expanded = false;
            _searchController.clear();
          });
        });
      }
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    _searchFocusNode.dispose();
    super.dispose();
  }

  void _toggleExpanded(FormFieldState<T> state) {
    if (!widget.enabled) return;
    setState(() {
      _expanded = !_expanded;
      if (!_expanded) {
        _searchController.clear();
      }
    });
    if (_expanded) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        _searchFocusNode.requestFocus();
      });
    }
    state.validate();
  }

  void _selectOption(FormFieldState<T> state, T? value) {
    widget.onChanged(value);
    state.didChange(value);
    setState(() {
      _expanded = false;
      _searchController.clear();
    });
    _searchFocusNode.unfocus();
  }

  @override
  Widget build(BuildContext context) {
    final chrome = AppChromeTheme.of(context);

    return FormField<T>(
      initialValue: widget.value,
      validator: widget.validator,
      builder: (state) {
        final textStyle = Theme.of(context).textTheme.bodyLarge?.copyWith(
              color: widget.enabled ? chrome.textColor : chrome.mutedColor,
            );

        final query = _searchController.text.toLowerCase();
        final filtered = query.isEmpty
            ? widget.options
            : widget.options.where((o) => o.label.toLowerCase().contains(query)).toList();

        Widget collapsedField() {
          return Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: () => _toggleExpanded(state),
              borderRadius: BorderRadius.circular(16),
              child: InputDecorator(
                decoration: InputDecoration(
                  labelText: widget.label,
                  filled: true,
                  enabled: widget.enabled,
                  fillColor: chrome.surfaceColor,
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(16)),
                  errorText: state.errorText,
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        widget.displayValue.isEmpty ? 'Select' : widget.displayValue,
                        style: textStyle,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    Icon(Icons.filter_list, color: chrome.mutedColor),
                  ],
                ),
              ),
            ),
          );
        }

        Widget expandedPanel() {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              DecoratedBox(
                decoration: BoxDecoration(
                  color: chrome.mutedColor.withOpacity(0.18),
                  borderRadius: BorderRadius.circular(18),
                ),
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(10, 10, 10, 10),
                  child: Column(
                    children: [
                      TextField(
                        controller: _searchController,
                        focusNode: _searchFocusNode,
                        onChanged: (_) => setState(() {}),
                        decoration: InputDecoration(
                          hintText: 'Search for ${widget.label}',
                          filled: true,
                          fillColor: chrome.surfaceColor,
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(14),
                          ),
                          suffixIcon: Icon(Icons.filter_list, color: chrome.mutedColor),
                        ),
                      ),
                      const SizedBox(height: 10),
                      ConstrainedBox(
                        constraints: const BoxConstraints(maxHeight: 240),
                        child: filtered.isEmpty
                            ? Padding(
                                padding: const EdgeInsets.symmetric(vertical: 12),
                                child: Align(
                                  alignment: Alignment.centerLeft,
                                  child: Text(
                                    'No matches found',
                                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                          color: chrome.mutedColor,
                                          fontWeight: FontWeight.w700,
                                        ),
                                  ),
                                ),
                              )
                            : ListView.builder(
                                shrinkWrap: true,
                                itemCount: filtered.length,
                                itemBuilder: (context, index) {
                                  final option = filtered[index];
                                  final isSelected = option.value == state.value;
                                  return Padding(
                                    padding: const EdgeInsets.symmetric(vertical: 5),
                                    child: Material(
                                      color: chrome.surfaceColor,
                                      borderRadius: BorderRadius.circular(14),
                                      child: InkWell(
                                        borderRadius: BorderRadius.circular(14),
                                        onTap: () => _selectOption(state, option.value),
                                        child: Container(
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: 14,
                                            vertical: 14,
                                          ),
                                          decoration: BoxDecoration(
                                            borderRadius: BorderRadius.circular(14),
                                            border: Border.all(
                                              color: isSelected
                                                  ? chrome.textColor.withOpacity(0.55)
                                                  : Colors.transparent,
                                            ),
                                          ),
                                          child: Row(
                                            children: [
                                              Expanded(
                                                child: Text(
                                                  option.label,
                                                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                                        fontWeight: FontWeight.w700,
                                                        color: chrome.textColor,
                                                      ),
                                                ),
                                              ),
                                              if (isSelected) Icon(Icons.check, color: chrome.textColor),
                                            ],
                                          ),
                                        ),
                                      ),
                                    ),
                                  );
                                },
                              ),
                      ),
                    ],
                  ),
                ),
              ),
              if (state.errorText != null) ...[
                const SizedBox(height: 6),
                Text(
                  state.errorText!,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: Theme.of(context).colorScheme.error,
                        fontWeight: FontWeight.w700,
                      ),
                ),
              ],
            ],
          );
        }

        return AnimatedSize(
          duration: const Duration(milliseconds: 160),
          curve: Curves.easeOut,
          alignment: Alignment.topCenter,
          child: _expanded ? expandedPanel() : collapsedField(),
        );
      },
    );
  }
}

class _PaymentNumberField extends StatelessWidget {
  const _PaymentNumberField({
    required this.label,
    required this.value,
    required this.min,
    required this.max,
    required this.onChanged,
    this.enabled = true,
  });

  final String label;
  final int value;
  final int min;
  final int max;
  final ValueChanged<int> onChanged;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    final chrome = AppChromeTheme.of(context);

    final canDec = enabled && value > min;
    final canInc = enabled && value < max;

    return Opacity(
      opacity: enabled ? 1.0 : 0.55,
      child: InputDecorator(
        decoration: InputDecoration(
          labelText: label,
          filled: true,
          fillColor: chrome.surfaceColor,
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(16)),
        ),
        child: Row(
          children: [
            IconButton(
              onPressed: canDec ? () => onChanged(value - 1) : null,
              icon: const Icon(Icons.remove),
              splashRadius: 18,
            ),
            Expanded(
              child: Center(
                child: Text(
                  '$value',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w800,
                        color: chrome.textColor,
                      ),
                ),
              ),
            ),
            IconButton(
              onPressed: canInc ? () => onChanged(value + 1) : null,
              icon: const Icon(Icons.add),
              splashRadius: 18,
            ),
          ],
        ),
      ),
    );
  }
}
