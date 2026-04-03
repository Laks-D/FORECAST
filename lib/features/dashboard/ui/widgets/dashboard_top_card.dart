import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/services/notification_cubit.dart';
import '../../../../core/utils/date_utils.dart';
import '../../../../design_system/theme/app_chrome_theme.dart';
import '../../../calendar/bloc/sessions_cubit.dart';
import '../../../notifications/ui/notifications_page.dart';
import '../../bloc/dashboard_cubit.dart';
import '../../bloc/dashboard_state.dart';
import 'dashboard_meter.dart';

class DashboardTopCard extends StatelessWidget {
  const DashboardTopCard({super.key, this.height = 210});

  final double height;

  @override
  Widget build(BuildContext context) {
    final chrome = AppChromeTheme.of(context);
    final textColor = chrome.textColor;

    final titleStyle = Theme.of(context).textTheme.titleMedium?.copyWith(
          color: textColor,
          fontWeight: FontWeight.w900,
          letterSpacing: -0.5,
        );

    return SizedBox(
      height: height,
      child: Container(
        decoration: BoxDecoration(
          color: chrome.surfaceColor,
          borderRadius: BorderRadius.circular(28),
          border: Border.all(color: chrome.mutedColor.withOpacity(0.12)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.2),
              blurRadius: 15,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 20, 20, 20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // HEADER ROW
              BlocSelector<DashboardCubit, DashboardState, String>(
                selector: (state) => state.userName ?? 'User',
                builder: (context, name) {
                  return Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                        decoration: BoxDecoration(
                          color: chrome.mutedColor.withOpacity(0.05),
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(color: chrome.mutedColor.withOpacity(0.08)),
                        ),
                        child: Text(
                          'HEY, ${name.toUpperCase()}',
                          style: titleStyle?.copyWith(
                            fontSize: 12,
                            color: chrome.textColor,
                            fontWeight: FontWeight.w900,
                            letterSpacing: 1.0,
                          ),
                        ),
                      ),
                      const Spacer(),
                      BlocBuilder<NotificationCubit, NotificationState>(
                        builder: (context, nState) {
                          final unread = nState.unreadCount;
                          return Stack(
                            clipBehavior: Clip.none,
                            children: [
                              Container(
                                decoration: BoxDecoration(
                                  color: chrome.mutedColor.withOpacity(0.05),
                                  shape: BoxShape.circle,
                                  border: Border.all(color: chrome.mutedColor.withOpacity(0.08)),
                                ),
                                child: IconButton(
                                  icon: Icon(
                                    Icons.notifications_none_rounded,
                                    color: chrome.textColor,
                                    size: 22,
                                  ),
                                  visualDensity: VisualDensity.compact,
                                  onPressed: () {
                                    Navigator.of(context).push(
                                      MaterialPageRoute<void>(
                                        builder: (_) => BlocProvider.value(
                                          value: context.read<NotificationCubit>(),
                                          child: const NotificationsPage(),
                                        ),
                                      ),
                                    );
                                  },
                                ),
                              ),
                              if (unread > 0)
                                Positioned(
                                  right: 0,
                                  top: 0,
                                  child: Container(
                                    width: 10,
                                    height: 10,
                                    decoration: const BoxDecoration(
                                      color: VibrantColors.pastelGreen,
                                      shape: BoxShape.circle,
                                    ),
                                  ),
                                ),
                            ],
                          );
                        },
                      ),
                    ],
                  );
                },
              ),
              // Removed spacer to give more room for the meter below
              // STATS CONTENT
              Expanded(
                child: BlocBuilder<SessionsCubit, SessionsState>(
                  builder: (context, sessionsState) {
                    final targetStr = AppDateUtils.dateToStr(DateTime.now());
                    final sessionsForDay = sessionsState.sessions
                        .where((s) => s.date == targetStr)
                        .where(
                          (s) =>
                              AppDateUtils.determineSessionStatus(
                                s.status,
                                s.date,
                                s.time,
                              ) !=
                              'Cancelled',
                        )
                        .toList();

                    final completed = sessionsForDay.where((s) {
                      return AppDateUtils.determineSessionStatus(
                            s.status,
                            s.date,
                            s.time,
                          ) ==
                          'Completed';
                    }).length;

                    final upcoming = sessionsForDay.where((s) {
                      return AppDateUtils.determineSessionStatus(
                            s.status,
                            s.date,
                            s.time,
                          ) ==
                          'Upcoming';
                    }).length;

                    final pending = sessionsForDay.where((s) {
                      return AppDateUtils.determineSessionStatus(
                            s.status,
                            s.date,
                            s.time,
                          ) ==
                          'Pending';
                    }).length;

                    final total = sessionsForDay.length;

                    final displayTotal = total;

                    return LayoutBuilder(
                      builder: (context, constraints) {
                        final availableW = constraints.maxWidth;
                        final availableH = constraints.maxHeight;

                        const rightColumnW = 150.0;
                        const gap = 16.0;
                        final meterW = (availableW - rightColumnW - gap).clamp(160.0, 240.0);
                        final meterH = availableH.clamp(110.0, 150.0);

                        Widget statChip({
                          required String label,
                          required int value,
                          required Color color,
                        }) {
                          return Container(
                            height: double.infinity,
                            padding: const EdgeInsets.symmetric(horizontal: 12),
                            decoration: BoxDecoration(
                              color: color.withOpacity(0.08),
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(color: color.withOpacity(0.16)),
                            ),
                            alignment: Alignment.center,
                            child: Row(
                              children: [
                                Container(
                                  width: 10,
                                  height: 10,
                                  decoration: BoxDecoration(
                                    color: color,
                                    shape: BoxShape.circle,
                                    boxShadow: [
                                      BoxShadow(
                                        color: color.withOpacity(0.4),
                                        blurRadius: 6,
                                        spreadRadius: 1,
                                      ),
                                    ],
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Text(
                                    label.toUpperCase(),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: Theme.of(context).textTheme.labelSmall?.copyWith(
                                          color: chrome.mutedColor,
                                          fontWeight: FontWeight.w900,
                                          letterSpacing: 0.8,
                                        ),
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Text(
                                  '$value',
                                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                                        color: Colors.white,
                                        fontWeight: FontWeight.w900,
                                        fontSize: 18,
                                      ),
                                ),
                              ],
                            ),
                          );
                        }

                        return Padding(
                          padding: const EdgeInsets.symmetric(vertical: 4),
                          child: Row(
                            children: [
                              Expanded(
                                child: Align(
                                  alignment: Alignment.centerLeft,
                                  child: SizedBox(
                                    width: meterW.toDouble(),
                                    height: meterH.toDouble(),
                                    child: DashboardMeter(
                                      size: meterW.toDouble(),
                                      completed: completed,
                                      pending: pending,
                                      upcoming: upcoming,
                                      total: total,
                                      centerValue: '$completed/$displayTotal',
                                      centerLabel: '',
                                      strokeWidth: 20,
                                      trackColor: chrome.mutedColor.withOpacity(0.08),
                                      textColor: chrome.textColor,
                                    ),
                                  ),
                                ),
                              ),
                              const SizedBox(width: gap),
                              SizedBox(
                                width: rightColumnW,
                                child: Column(
                                  children: [
                                    Expanded(
                                      child: statChip(
                                        label: 'Pending',
                                        value: pending,
                                        color: VibrantColors.softPink,
                                      ),
                                    ),
                                    const SizedBox(height: 12),
                                    Expanded(
                                      child: statChip(
                                        label: 'Upcoming',
                                        value: upcoming,
                                        color: VibrantColors.warmYellow,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        );
                      },
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
