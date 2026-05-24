import 'dart:async';

import 'package:bloc/bloc.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../../dashboard/bloc/dashboard_state.dart';
import '../../../core/app/app_mode.dart';
import '../../../core/services/user_firestore_sync.dart';
import 'nav_modules_state.dart';

class NavModulesCubit extends Cubit<NavModulesState> {
  NavModulesCubit() : super(NavModulesState.defaults()) {
    _authSub = FirebaseAuth.instance.authStateChanges().listen((_) => _load());
    _load();
  }

  StreamSubscription<User?>? _authSub;

  static String get _settingsKey => AppModeConfig.isClient ? 'navModulesClient' : 'navModulesAdmin';

  static List<DashboardTab> get _supportedTabs => AppModeConfig.isClient
      ? const <DashboardTab>[
          DashboardTab.people,
          DashboardTab.calendar,
          DashboardTab.home,
          DashboardTab.phone,
          DashboardTab.settings,
        ]
      : const <DashboardTab>[
          DashboardTab.calendar,
          DashboardTab.people,
          DashboardTab.home,
          DashboardTab.phone,
          DashboardTab.settings,
        ];

  Future<void> toggleEnabled(DashboardTab tab, bool enabled) async {
    // Safety: keep Dashboard always available.
    if (tab == DashboardTab.home) return;
    // Safety: keep Profile/Settings always available.
    if (tab == DashboardTab.settings) return;

    final currentEnabled = state.enabled.toSet();
    if (enabled) {
      currentEnabled.add(tab);
    } else {
      currentEnabled.remove(tab);
    }
    // Ensure Dashboard is always enabled.
    currentEnabled.add(DashboardTab.home);
    // Ensure Profile is always enabled.
    currentEnabled.add(DashboardTab.settings);

    // Ensure we never end up with 0 visible tabs.
    if (currentEnabled.isEmpty) {
      currentEnabled.add(DashboardTab.home);
      currentEnabled.add(DashboardTab.settings);
    }

    final nextEnabled = _normalizeTabs(currentEnabled.toList());
    _emitNormalized(order: state.order, enabled: nextEnabled, isLoaded: state.isLoaded);
    await _persist();
  }

  Future<void> reorder(int oldIndex, int newIndex) async {
    final list = [...state.order];
    if (oldIndex < 0 || oldIndex >= list.length) return;

    // ReorderableListView gives newIndex as if the item is removed first.
    final adjustedNewIndex = newIndex > oldIndex ? newIndex - 1 : newIndex;
    if (adjustedNewIndex < 0 || adjustedNewIndex >= list.length) return;

    final item = list.removeAt(oldIndex);
    list.insert(adjustedNewIndex, item);

    _emitNormalized(order: list, enabled: state.enabled, isLoaded: state.isLoaded);
    await _persist();
  }

  Future<void> resetDefaults() async {
    final defaults = NavModulesState.defaults();
    emit(defaults.copyWith(isLoaded: true));
    await _persist();
  }

  Future<void> _load() async {
    try {
      final settings = await UserFirestoreSync.instance.loadSettings();
      final raw = settings?[_settingsKey];
      Map<String, dynamic>? jsonMap;
      if (raw is Map<String, dynamic>) {
        jsonMap = raw;
      } else if (raw is Map) {
        jsonMap = Map<String, dynamic>.from(raw);
      }

      if (jsonMap == null) {
        emit(state.copyWith(isLoaded: true));
        return;
      }

      var orderStrings = (jsonMap['order'] as List?)?.whereType<String>().toList() ?? const <String>[];
      final enabledStrings = (jsonMap['enabled'] as List?)?.whereType<String>().toList() ?? const <String>[];

      // Migration: older versions persisted the old default order. If the user
      // never customized their nav order (i.e., it matches the old default
      // exactly), update it to the new default (People before Calendar).
      const oldDefault = <String>[
        'calendar',
        'people',
        'home',
        'phone',
        'settings',
      ];

      if (orderStrings.length == oldDefault.length) {
        var matchesOldDefault = true;
        for (var i = 0; i < oldDefault.length; i++) {
          if (orderStrings[i] != oldDefault[i]) {
            matchesOldDefault = false;
            break;
          }
        }

        if (matchesOldDefault) {
          orderStrings = const <String>[
            'people',
            'calendar',
            'home',
            'phone',
            'settings',
          ];
        }
      }

      final order = _parseTabList(orderStrings);
      final enabled = _parseTabList(enabledStrings).toSet()
        ..add(DashboardTab.home)
        ..add(DashboardTab.settings);

      // Ensure a complete order list (in case older data is missing tabs).
      final fullOrder = _ensureAllTabs(order);

      _emitNormalized(order: fullOrder, enabled: enabled.toList(), isLoaded: true);
    } catch (_) {
      emit(state.copyWith(isLoaded: true));
    }
  }

  Future<void> _persist() async {
    try {
      final payload = <String, Object?>{
        'order': state.order.map(_tabToKey).toList(growable: false),
        'enabled': state.enabled.map(_tabToKey).toList(growable: false),
      };
      await UserFirestoreSync.instance.patchSettingsNow({_settingsKey: payload});
    } catch (_) {
      // Ignore persistence failures; keep UI responsive.
    }
  }

  void _emitNormalized({required List<DashboardTab> order, required List<DashboardTab> enabled, required bool isLoaded}) {
    final normalizedOrder = _ensureAllTabs(_normalizeTabs(order));
    final enabledSet = _normalizeTabs(enabled).toSet()
      ..add(DashboardTab.home)
      ..add(DashboardTab.settings);

    final visibleTabs = normalizedOrder.where(enabledSet.contains).toList(growable: false);
    emit(
      state.copyWith(
        order: normalizedOrder,
        enabled: enabledSet.toList(growable: false),
        visibleTabs: visibleTabs.isEmpty
            ? const [DashboardTab.home, DashboardTab.settings]
            : visibleTabs,
        isLoaded: isLoaded,
      ),
    );
  }

  List<DashboardTab> _normalizeTabs(List<DashboardTab> tabs) {
    final seen = <DashboardTab>{};
    final out = <DashboardTab>[];
    for (final t in tabs) {
      if (!_supportedTabs.contains(t)) continue;
      if (seen.add(t)) out.add(t);
    }
    return out;
  }

  List<DashboardTab> _ensureAllTabs(List<DashboardTab> order) {
    final all = _supportedTabs;

    final set = order.toSet();
    final out = [...order];
    for (final t in all) {
      if (!set.contains(t)) out.add(t);
    }
    return out;
  }

  List<DashboardTab> _parseTabList(List<String> keys) {
    final out = <DashboardTab>[];
    for (final k in keys) {
      final t = _keyToTab(k);
      if (t != null) out.add(t);
    }
    return out;
  }

  static String _tabToKey(DashboardTab tab) => tab.name;

  static DashboardTab? _keyToTab(String key) {
    for (final t in DashboardTab.values) {
      if (t.name == key) return t;
    }
    return null;
  }

  @override
  Future<void> close() async {
    await _authSub?.cancel();
    return super.close();
  }
}
