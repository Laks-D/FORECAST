import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/utils/date_utils.dart';
import '../../../../design_system/theme/app_chrome_theme.dart';
import '../../../calendar/bloc/sessions_cubit.dart';
import '../../../calendar/ui/widgets/calendar_page_body.dart';
import '../../../client/presentation/pages/client_page.dart';
import '../../../navigation/bloc/nav_modules_cubit.dart';
import '../../../navigation/bloc/nav_modules_state.dart';
import '../../../payment/presentation/pages/payments_page.dart';
import '../../../settings/ui/settings_page_body.dart';
import '../../bloc/dashboard_cubit.dart';
import '../../bloc/dashboard_state.dart';
import 'dashboard_bottom_nav.dart';
import 'dashboard_free_today_card.dart';
import 'dashboard_middle_card.dart';
import 'dashboard_top_card.dart';

class DashboardPhoneFrame extends StatelessWidget {
  const DashboardPhoneFrame({super.key});

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final w = constraints.maxWidth;
        final h = constraints.maxHeight;
        final statusTop = MediaQuery.viewPaddingOf(context).top;
        final frameColor = AppChromeTheme.of(context).frameColor;

        final horizontalPadding = (w * 0.045).clamp(12.0, 20.0);
        final topPadding = statusTop + (h * 0.012).clamp(6.0, 14.0);
        const bottomPadding = 10.0;
        const navHeight = 68.0;
        const navGap = 6.0;

        final contentH = (h - topPadding - bottomPadding - navHeight - navGap).clamp(480.0, 4000.0);
        final topCardH = (contentH * 0.29).clamp(180.0, 260.0);
        final gapBetweenCards = (contentH * 0.04).clamp(8.0, 14.0);
        final middleCardH = (contentH - topCardH - gapBetweenCards).clamp(330.0, 4000.0);

        return SizedBox.expand(
          child: BlocListener<NavModulesCubit, NavModulesState>(
            listenWhen: (prev, next) => prev.visibleTabs != next.visibleTabs,
            listener: (context, navState) {
              final current = context.read<DashboardCubit>().state.tab;
              if (!navState.visibleTabs.contains(current) && navState.visibleTabs.isNotEmpty) {
                context.read<DashboardCubit>().selectTab(navState.visibleTabs.first);
              }
            },
            child: Stack(
              children: [
              Positioned.fill(
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    color: frameColor,
                  ),
                ),
              ),

              // Keep the entire status-bar area solid red.
              Positioned(
                top: 0,
                left: 0,
                right: 0,
                child: SizedBox(
                  height: statusTop,
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      color: frameColor,
                    ),
                  ),
                ),
              ),

              Positioned.fill(
                child: Padding(
                  padding: EdgeInsets.fromLTRB(horizontalPadding, topPadding, horizontalPadding, bottomPadding),
                  child: Column(
                    children: [
                      Expanded(
                        child: BlocSelector<DashboardCubit, DashboardState, DashboardTab>(
                          selector: (s) => s.tab,
                          builder: (context, tab) {
                            if (tab == DashboardTab.calendar) {
                              return const CalendarPageBody();
                            }

                            if (tab == DashboardTab.people) {
                              return const ClientPage(embedInDashboard: true);
                            }

                            if (tab == DashboardTab.phone) {
                              return const PaymentsPage(embedInDashboard: true);
                            }

                            if (tab == DashboardTab.settings) {
                              return const SettingsPageBody();
                            }

                            return BlocBuilder<SessionsCubit, SessionsState>(
                              builder: (context, sessionsState) {
                                final todayStr = AppDateUtils.dateToStr(DateTime.now());
                                final todayCount = sessionsState.sessions
                                    .where((s) => s.date == todayStr)
                                    .where(
                                      (s) =>
                                          AppDateUtils.determineSessionStatus(
                                            s.status,
                                            s.date,
                                            s.time,
                                          ) !=
                                          'Cancelled',
                                    )
                                    .length;

                                if (todayCount == 0) {
                                  return Column(
                                    children: [
                                      DashboardTopCard(height: topCardH),
                                      SizedBox(height: gapBetweenCards),
                                      DashboardFreeTodayCard(height: middleCardH),
                                    ],
                                  );
                                }

                                return Column(
                                  children: [
                                    DashboardTopCard(height: topCardH),
                                    SizedBox(height: gapBetweenCards),
                                    DashboardMiddleCard(height: middleCardH),
                                  ],
                                );
                              },
                            );
                          },
                        ),
                      ),
                      const SizedBox(height: navGap),
                      DashboardBottomNav(
                        onTabSelected: (tab) => context.read<DashboardCubit>().selectTab(tab),
                      ),
                    ],
                  ),
                ),
              ),
              ],
            ),
          ),
        );
      },
    );
  }
}
