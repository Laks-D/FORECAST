import 'dart:convert';

import 'package:bloc/bloc.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../dashboard/bloc/dashboard_state.dart';
import '../../../core/services/user_firestore_sync.dart';
import 'nav_modules_state.dart';

class NavModulesCubit extends Cubit<NavModulesState> {
  NavModulesCubit() : super(NavModulesState.defaults()) {
    _load();
  }

  static const _prefsKey = 'nav_modules_v1';
  static const _supportedTabs = <DashboardTab>[
    DashboardTab.calendar,
    DashboardTab.people,
    DashboardTab.home,
    DashboardTab.phone,
    DashboardTab.settings,
  ];

  Future<void> toggleEnabled(DashboardTab tab, bool enabled) async {
    // Safety: keep Dashboard and Profile always available.
    if (tab == DashboardTab.home || tab == DashboardTab.settings) return;

    final currentEnabled = state.enabled.toSet();
    if (enabled) {
      currentEnabled.add(tab);
    } else {
      currentEnabled.remove(tab);
    }
    // Ensure Dashboard + Profile are always enabled.
    currentEnabled.add(DashboardTab.home);
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
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_prefsKey);
      if (raw == null || raw.trim().isEmpty) {
        emit(state.copyWith(isLoaded: true));
        return;
      }

      final jsonMap = json.decode(raw);
      if (jsonMap is! Map<String, dynamic>) {
        emit(state.copyWith(isLoaded: true));
        return;
      }

      final orderStrings = (jsonMap['order'] as List?)?.whereType<String>().toList() ?? const <String>[];
      final enabledStrings = (jsonMap['enabled'] as List?)?.whereType<String>().toList() ?? const <String>[];

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
      final prefs = await SharedPreferences.getInstance();
      final payload = <String, Object?>{
        'order': state.order.map(_tabToKey).toList(growable: false),
        'enabled': state.enabled.map(_tabToKey).toList(growable: false),
      };
      await prefs.setString(_prefsKey, json.encode(payload));

      UserFirestoreSync.instance.scheduleSettingsPatch({'navModules': payload});
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
        visibleTabs: visibleTabs.isEmpty ? const [DashboardTab.home, DashboardTab.settings] : visibleTabs,
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
    const all = _supportedTabs;

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
}
