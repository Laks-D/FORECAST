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
      child: Container(
        height: 64,
        margin: EdgeInsets.only(
          left: 16, 
          right: 16, 
          bottom: 16 + MediaQuery.viewPaddingOf(context).bottom,
        ),
        decoration: BoxDecoration(
          color: const Color(0xFF1E1E24), // Dark pill color
          borderRadius: BorderRadius.circular(32),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.3),
              blurRadius: 20,
              offset: const Offset(0, 10),
            ),
          ],
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              for (final tab in _tabs)
                _NavIcon(
                  tab: tab,
                  icon: _iconFor(tab),
                  onTap: () => widget.onTabSelected(tab),
                ),
            ],
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
        final iconColor = selected ? const Color(0xFF1E1E24) : scheme.onSurface.withOpacity(0.9);
        final bgColor = selected ? Colors.white : Colors.transparent;
        
        return InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(30),
          highlightColor: Colors.transparent,
          splashColor: scheme.onSurface.withOpacity(0.05),
          child: Padding(
            padding: const EdgeInsets.all(6.0),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 240),
              curve: Curves.easeOutCubic,
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: bgColor,
                shape: BoxShape.circle,
              ),
              alignment: Alignment.center,
              child: Icon(
                icon,
                size: 24,
                color: iconColor,
              ),
            ),
          ),
        );
      },
    );
  }
}
