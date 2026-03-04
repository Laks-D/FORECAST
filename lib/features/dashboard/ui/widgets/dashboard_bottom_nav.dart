import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'dart:math' as math;
import 'dart:ui' show lerpDouble;

import '../../../navigation/bloc/nav_modules_cubit.dart';
import '../../../navigation/bloc/nav_modules_state.dart';
import '../../bloc/dashboard_cubit.dart';
import '../../bloc/dashboard_state.dart';

class DashboardBottomNav extends StatefulWidget {
  const DashboardBottomNav({super.key, required this.onTabSelected});

  final ValueChanged<DashboardTab> onTabSelected;

  @override
  State<DashboardBottomNav> createState() => _DashboardBottomNavState();
}

class _DashboardBottomNavState extends State<DashboardBottomNav> with SingleTickerProviderStateMixin {
  List<DashboardTab> _tabs = const <DashboardTab>[
    DashboardTab.calendar,
    DashboardTab.people,
    DashboardTab.home,
    DashboardTab.phone,
    DashboardTab.settings,
  ];

  late final AnimationController _controller;
  late int _fromIndex;
  late int _toIndex;
  bool _syncedFromCubit = false;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 320),
    );
    _fromIndex = _tabs.indexOf(DashboardTab.home);
    _toIndex = _fromIndex;
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_syncedFromCubit) return;
    final navTabs = context.read<NavModulesCubit>().state.visibleTabs;
    if (navTabs.isNotEmpty) {
      _tabs = navTabs;
    }
    final currentTab = context.read<DashboardCubit>().state.tab;
    final idx = _tabs.indexOf(currentTab);
    if (idx >= 0) {
      _fromIndex = idx;
      _toIndex = idx;
    } else if (_tabs.isNotEmpty) {
      _fromIndex = 0;
      _toIndex = 0;
    }
    _syncedFromCubit = true;
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _animateTo(DashboardTab tab) {
    final next = _tabs.indexOf(tab);
    if (next < 0 || next == _toIndex) return;
    _fromIndex = _toIndex;
    _toIndex = next;
    _controller.forward(from: 0);
  }

  @override
  Widget build(BuildContext context) {
    return MultiBlocListener(
      listeners: [
        BlocListener<DashboardCubit, DashboardState>(
          listenWhen: (prev, next) => prev.tab != next.tab,
          listener: (context, state) => _animateTo(state.tab),
        ),
        BlocListener<NavModulesCubit, NavModulesState>(
          listenWhen: (prev, next) => prev.visibleTabs != next.visibleTabs,
          listener: (context, navState) {
            if (navState.visibleTabs.isEmpty) return;

            setState(() {
              _tabs = navState.visibleTabs;
              final currentTab = context.read<DashboardCubit>().state.tab;
              final idx = _tabs.indexOf(currentTab);
              if (idx >= 0) {
                _fromIndex = idx;
                _toIndex = idx;
              } else {
                _fromIndex = 0;
                _toIndex = 0;
              }
            });
          },
        ),
      ],
      child: SizedBox(
        height: 68,
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(34),
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: LayoutBuilder(
              builder: (context, constraints) {
                final slots = _tabs.isEmpty ? 1 : _tabs.length;
                final slotW = constraints.maxWidth / slots;
                double centerForIndex(int index) => slotW * (index + 0.5);
                final bubbleSize = math.min(54.0, math.max(38.0, slotW - 8));

                return Stack(
                  alignment: Alignment.centerLeft,
                  children: [
                    // Rolling selection bubble.
                    AnimatedBuilder(
                      animation: _controller,
                      builder: (context, _) {
                        final safeFrom = _fromIndex.clamp(0, slots - 1);
                        final safeTo = _toIndex.clamp(0, slots - 1);
                        final t = Curves.easeOutCubic.transform(_controller.value);
                        final fromC = centerForIndex(safeFrom);
                        final toC = centerForIndex(safeTo);
                        final currentC = lerpDouble(fromC, toC, t) ?? toC;
                        final delta = (safeTo - safeFrom);
                        final sign = delta == 0 ? 1.0 : delta.sign.toDouble();
                        final amplitude = 0.08 + 0.02 * math.min(delta.abs(), 3);
                        final turns = math.sin(math.pi * t) * amplitude * sign;

                        return Positioned(
                          left: currentC - (bubbleSize / 2),
                          child: Transform.rotate(
                            angle: turns * 2 * math.pi,
                            child: DecoratedBox(
                              decoration: const BoxDecoration(
                                color: Color(0xFFE9E9E9),
                                shape: BoxShape.circle,
                              ),
                              child: SizedBox(
                                width: bubbleSize,
                                height: bubbleSize,
                              ),
                            ),
                          ),
                        );
                      },
                    ),

                    // Icons row (tap targets), kept above the bubble.
                    Row(
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
                  ],
                );
              },
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
      return Icons.group_outlined;
    case DashboardTab.cards:
      return Icons.menu_book_outlined;
    case DashboardTab.home:
      return Icons.home_outlined;
    case DashboardTab.phone:
      return Icons.credit_card_outlined;
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
    return BlocSelector<DashboardCubit, DashboardState, bool>(
      selector: (state) => state.tab == tab,
      builder: (context, selected) {
        final color = selected ? Colors.black87 : Colors.black.withOpacity(0.65);
        return InkResponse(
          onTap: onTap,
          radius: 26,
          child: SizedBox(
            height: 52,
            child: Center(
              child: Icon(
                icon,
                size: 24,
                color: color,
              ),
            ),
          ),
        );
      },
    );
  }
}
