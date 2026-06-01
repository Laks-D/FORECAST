import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../design_system/theme/app_chrome_theme.dart';
import '../../../navigation/bloc/nav_modules_cubit.dart';
import '../../../navigation/bloc/nav_modules_state.dart';
import '../../bloc/dashboard_cubit.dart';
import '../../bloc/dashboard_state.dart';
import '../../../../core/app/app_mode.dart';

class DashboardBottomNav extends StatefulWidget {
  const DashboardBottomNav({super.key, required this.onTabSelected});

  final ValueChanged<DashboardTab> onTabSelected;

  @override
  State<DashboardBottomNav> createState() => _DashboardBottomNavState();
}

class _DashboardBottomNavState extends State<DashboardBottomNav> {
  List<DashboardTab> _tabs = const <DashboardTab>[
    DashboardTab.people,
    DashboardTab.calendar,
    DashboardTab.home,
    DashboardTab.phone,
    DashboardTab.settings,
  ];

  bool _syncedFromCubit = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_syncedFromCubit) return;
    final navTabs = context.read<NavModulesCubit>().state.visibleTabs;
    if (navTabs.isNotEmpty) {
      _tabs = navTabs;
    }
    _syncedFromCubit = true;
  }

  @override
  Widget build(BuildContext context) {
    return MultiBlocListener(
      listeners: [
        BlocListener<NavModulesCubit, NavModulesState>(
          listenWhen: (prev, next) => prev.visibleTabs != next.visibleTabs,
          listener: (context, navState) {
            if (navState.visibleTabs.isEmpty) return;
            setState(() {
              _tabs = navState.visibleTabs;
            });
          },
        ),
      ],
      child: SizedBox(
        height: 68,
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: Theme.of(context).scaffoldBackgroundColor,
            border: Border(
              top: BorderSide(
                color: Theme.of(context)
                    .colorScheme
                    .outlineVariant
                    .withOpacity(0.65),
              ),
            ),
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                for (final tab in _tabs)
                  Expanded(
                    child: _NavIcon(
                      tab: tab,
                      icon: _iconFor(tab),
                      onTap: () => widget.onTabSelected(tab),
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

IconData _iconFor(DashboardTab tab) {
  switch (tab) {
    case DashboardTab.calendar:
      return Icons.calendar_month_outlined;
    case DashboardTab.people:
      return AppModeConfig.isClient ? Icons.school_outlined : Icons.group_outlined;
    case DashboardTab.cards:
      return Icons.menu_book_outlined;
    case DashboardTab.home:
      return Icons.home_outlined;
    case DashboardTab.phone:
      return Icons.receipt_long_outlined;
    case DashboardTab.settings:
      return Icons.person_outline;
  }
}

class _NavIcon extends StatelessWidget {
  const _NavIcon({required this.tab, required this.icon, required this.onTap});

  final DashboardTab tab;
  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final chrome = AppChromeTheme.of(context);
    final scheme = Theme.of(context).colorScheme;
    return BlocSelector<DashboardCubit, DashboardState, bool>(
      selector: (state) => state.tab == tab,
      builder: (context, selected) {
        final color = selected ? scheme.onSurface : chrome.mutedColor;
        
        return InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(20),
          highlightColor: Colors.transparent,
          splashColor: scheme.onSurface.withOpacity(0.05),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              AnimatedContainer(
                duration: const Duration(milliseconds: 240),
                curve: Curves.easeOutCubic,
                padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
                child: Icon(
                  icon,
                  size: 26,
                  color: color,
                ),
              ),
              AnimatedContainer(
                duration: const Duration(milliseconds: 240),
                width: selected ? 4 : 0,
                height: selected ? 4 : 0,
                decoration: const BoxDecoration(
                  color: VibrantColors.pastelGreen,
                  shape: BoxShape.circle,
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
