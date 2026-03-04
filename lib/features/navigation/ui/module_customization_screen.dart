import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../dashboard/bloc/dashboard_state.dart';
import '../../../design_system/theme/app_chrome_theme.dart';
import '../bloc/nav_modules_cubit.dart';
import '../bloc/nav_modules_state.dart';

class ModuleCustomizationScreen extends StatelessWidget {
  const ModuleCustomizationScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final chrome = AppChromeTheme.of(context);

    return Scaffold(
      backgroundColor: chrome.frameColor,
      appBar: AppBar(
        backgroundColor: chrome.frameColor,
        foregroundColor: Colors.white,
        elevation: 0,
        title: const Text('Module customization'),
        actions: [
          TextButton(
            onPressed: () => context.read<NavModulesCubit>().resetDefaults(),
            style: TextButton.styleFrom(foregroundColor: Colors.white),
            child: const Text('Reset'),
          ),
        ],
      ),
      body: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(14, 12, 14, 14),
          child: DecoratedBox(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(28),
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(28),
              child: BlocBuilder<NavModulesCubit, NavModulesState>(
                builder: (context, state) {
                  return ReorderableListView.builder(
                    padding: const EdgeInsets.fromLTRB(12, 10, 12, 18),
                    itemCount: state.order.length,
                    buildDefaultDragHandles: false,
                    onReorder: (oldIndex, newIndex) => context.read<NavModulesCubit>().reorder(oldIndex, newIndex),
                    proxyDecorator: (child, index, animation) {
                      return AnimatedBuilder(
                        animation: animation,
                        child: child,
                        builder: (context, child) {
                          final t = Curves.easeOut.transform(animation.value);
                          return Material(
                            color: Colors.transparent,
                            elevation: 6 * t,
                            shadowColor: Colors.black.withOpacity(0.22),
                            borderRadius: BorderRadius.circular(18),
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(18),
                              child: child,
                            ),
                          );
                        },
                      );
                    },
                    itemBuilder: (context, index) {
                      final tab = state.order[index];
                      final isEnabled = state.enabled.contains(tab) || tab == DashboardTab.settings || tab == DashboardTab.home;
                      final isLocked = tab == DashboardTab.settings || tab == DashboardTab.home;

                      return Container(
                        key: ValueKey(tab),
                        margin: const EdgeInsets.only(bottom: 10),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          border: Border.all(color: Colors.black.withOpacity(0.08)),
                          borderRadius: BorderRadius.circular(18),
                        ),
                        child: ListTile(
                          leading: Icon(_iconFor(tab), color: Colors.black87),
                          title: Text(
                            _labelFor(tab),
                            style: Theme.of(context).textTheme.titleSmall?.copyWith(
                                  fontWeight: FontWeight.w700,
                                  color: Colors.black87,
                                ),
                          ),
                          subtitle: isLocked
                              ? Text(
                                  'Always available',
                                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                        color: Colors.black.withOpacity(0.55),
                                      ),
                                )
                              : null,
                          trailing: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Switch(
                                value: isEnabled,
                                onChanged: isLocked
                                    ? null
                                    : (v) => context.read<NavModulesCubit>().toggleEnabled(tab, v),
                              ),
                              ReorderableDragStartListener(
                                index: index,
                                child: const Padding(
                                  padding: EdgeInsets.only(left: 6),
                                  child: Icon(Icons.drag_handle),
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  );
                },
              ),
            ),
          ),
        ),
      ),
    );
  }

  static IconData _iconFor(DashboardTab tab) {
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

  static String _labelFor(DashboardTab tab) {
    switch (tab) {
      case DashboardTab.calendar:
        return 'Calendar';
      case DashboardTab.people:
        return 'Client';
      case DashboardTab.cards:
        return 'Cards';
      case DashboardTab.home:
        return 'Dashboard';
      case DashboardTab.phone:
        return 'Payment';
      case DashboardTab.settings:
        return 'Profile';
    }
  }
}
