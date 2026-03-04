import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/services/notification_cubit.dart';
import '../../../../core/utils/date_utils.dart';
import '../../../calendar/bloc/sessions_cubit.dart';
import '../../../notifications/ui/notifications_page.dart';
import '../../bloc/dashboard_cubit.dart';
import '../../bloc/dashboard_state.dart';
import 'dashboard_progress_ring.dart';

class DashboardTopCard extends StatelessWidget {
  const DashboardTopCard({super.key, this.height = 190});

  final double height;

  @override
  Widget build(BuildContext context) {
    final titleStyle = Theme.of(context).textTheme.titleMedium?.copyWith(
          color: Colors.black87,
          fontWeight: FontWeight.w700,
        );

    return SizedBox(
      height: height,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(40),
        ),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(18, 14, 18, 14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              BlocSelector<DashboardCubit, DashboardState, String>(
                selector: (state) => state.userName ?? 'User',
                builder: (context, name) {
                  return Row(
                    children: [
                      Expanded(
                        child: Text('Hey there, $name', style: titleStyle),
                      ),
                      BlocBuilder<NotificationCubit, NotificationState>(
                        builder: (context, nState) {
                          final unread = nState.unreadCount;
                          return Stack(
                            clipBehavior: Clip.none,
                            children: [
                              IconButton(
                                icon: const Icon(
                                  Icons.notifications_none_outlined,
                                  color: Colors.black87,
                                  size: 24,
                                ),
                                visualDensity: VisualDensity.compact,
                                padding: EdgeInsets.zero,
                                constraints: const BoxConstraints(),
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
                              if (unread > 0)
                                Positioned(
                                  right: -4,
                                  top: -4,
                                  child: Container(
                                    padding: const EdgeInsets.all(3),
                                    decoration: const BoxDecoration(
                                      color: Colors.red,
                                      shape: BoxShape.circle,
                                    ),
                                    constraints: const BoxConstraints(
                                      minWidth: 16,
                                      minHeight: 16,
                                    ),
                                    child: Text(
                                      unread > 9 ? '9+' : '$unread',
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontSize: 10,
                                        fontWeight: FontWeight.w700,
                                      ),
                                      textAlign: TextAlign.center,
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
              const SizedBox(height: 10),
              Expanded(
                child: Center(
                  child: BlocBuilder<SessionsCubit, SessionsState>(
                    builder: (context, sessionsState) {
                      final targetStr = AppDateUtils.dateToStr(DateTime.now());
                      final sessionsForDay = sessionsState.sessions
                          .where((s) => s.date == targetStr)
                          .toList();

                      final completed = sessionsForDay.where((s) {
                        return AppDateUtils.determineSessionStatus(
                              s.status,
                              s.date,
                              s.time,
                            ) ==
                            'Completed';
                      }).length;

                      final pending = sessionsForDay.where((s) {
                        return AppDateUtils.determineSessionStatus(
                              s.status,
                              s.date,
                              s.time,
                            ) ==
                            'Pending';
                      }).length;

                      final overdue = sessionsForDay.where((s) {
                        return AppDateUtils.determineSessionStatus(
                              s.status,
                              s.date,
                              s.time,
                            ) ==
                            'Overdue';
                      }).length;

                      final total = sessionsForDay.length;
                      final safeTotal = total <= 0 ? 1 : total;
                      final progress = (completed / safeTotal).clamp(0.0, 1.0);

                      return Row(
                        children: [
                          Expanded(
                            flex: 2,
                            child: Center(
                              child: _SideStat(value: '$pending', label: 'Pending'),
                            ),
                          ),
                          Expanded(
                            flex: 6,
                            child: Center(
                              child: LayoutBuilder(
                                builder: (context, constraints) {
                                  final s =
                                      (constraints.biggest.shortestSide * 0.98)
                                          .clamp(92.0, 200.0);
                                  return SizedBox(
                                    width: s,
                                    height: s,
                                    child: DashboardProgressRing(
                                      progress: progress,
                                      centerValue: '$completed',
                                      centerLabel: 'Completed',
                                      strokeWidth: 12,
                                      progressColor: const Color(0xFF58C7B3),
                                      trackColor: const Color(0xFFE6E6E6),
                                    ),
                                  );
                                },
                              ),
                            ),
                          ),
                          Expanded(
                            flex: 2,
                            child: Center(
                              child: _SideStat(value: '$overdue', label: 'Overdue'),
                            ),
                          ),
                        ],
                      );
                    },
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SideStat extends StatelessWidget {
  const _SideStat({required this.value, required this.label});

  final String value;
  final String label;

  @override
  Widget build(BuildContext context) {
    final valueStyle = Theme.of(context).textTheme.titleMedium?.copyWith(
          color: Colors.black87,
          fontWeight: FontWeight.w700,
        );
    final labelStyle = Theme.of(context).textTheme.labelSmall?.copyWith(
          color: Colors.black54,
          fontWeight: FontWeight.w500,
        );

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        FittedBox(
          fit: BoxFit.scaleDown,
          child: Text(value, style: valueStyle),
        ),
        const SizedBox(height: 2),
        Text(
          label,
          style: labelStyle,
          textAlign: TextAlign.center,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
      ],
    );
  }
}
