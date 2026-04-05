import 'package:equatable/equatable.dart';

import '../../dashboard/bloc/dashboard_state.dart';

final class NavModulesState extends Equatable {
  const NavModulesState({
    required this.order,
    required this.enabled,
    required this.visibleTabs,
    this.isLoaded = false,
  });

  factory NavModulesState.defaults() {
    const order = <DashboardTab>[
      DashboardTab.people,
      DashboardTab.calendar,
      DashboardTab.home,
      DashboardTab.phone,
      DashboardTab.settings,
    ];

    const enabled = <DashboardTab>[
      DashboardTab.people,
      DashboardTab.calendar,
      DashboardTab.home,
      DashboardTab.phone,
      DashboardTab.settings,
    ];

    return NavModulesState(
      order: order,
      enabled: enabled,
      visibleTabs: order,
      isLoaded: false,
    );
  }

  final List<DashboardTab> order;
  final List<DashboardTab> enabled;
  final List<DashboardTab> visibleTabs;

  /// True after we've attempted to load persisted preferences.
  final bool isLoaded;

  NavModulesState copyWith({
    List<DashboardTab>? order,
    List<DashboardTab>? enabled,
    List<DashboardTab>? visibleTabs,
    bool? isLoaded,
  }) {
    return NavModulesState(
      order: order ?? this.order,
      enabled: enabled ?? this.enabled,
      visibleTabs: visibleTabs ?? this.visibleTabs,
      isLoaded: isLoaded ?? this.isLoaded,
    );
  }

  @override
  List<Object?> get props => [order, enabled, visibleTabs, isLoaded];
}
