import 'dart:convert';

import 'package:bloc/bloc.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'widget_customization_state.dart';

class WidgetCustomizationCubit extends Cubit<WidgetCustomizationState> {
  WidgetCustomizationCubit() : super(WidgetCustomizationState.defaults()) {
    _load();
  }

  static const _prefsKey = 'widget_customization_v1';

  Future<void> setCalendarSelectionStyle(CalendarSelectionStyle style) async {
    if (state.calendarSelectionStyle == style) return;
    emit(state.copyWith(calendarSelectionStyle: style, isLoaded: state.isLoaded));
    await _persist();
  }

  Future<void> setMeterStyle(MeterStyle style) async {
    if (state.meterStyle == style) return;
    emit(state.copyWith(meterStyle: style, isLoaded: state.isLoaded));
    await _persist();
  }

  Future<void> setMeterColorStyle(MeterColorStyle style) async {
    if (state.meterColorStyle == style) return;
    emit(state.copyWith(meterColorStyle: style, isLoaded: state.isLoaded));
    await _persist();
  }

  Future<void> resetDefaults() async {
    emit(WidgetCustomizationState.defaults().copyWith(isLoaded: true));
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

      final decoded = json.decode(raw);
      if (decoded is! Map<String, dynamic>) {
        emit(state.copyWith(isLoaded: true));
        return;
      }

      final cal = _calendarSelectionFromKey(decoded['calendarSelectionStyle'] as String?);
      final meter = _meterStyleFromKey(decoded['meterStyle'] as String?);
      final meterColor = _meterColorFromKey(decoded['meterColorStyle'] as String?);

      emit(
        state.copyWith(
          calendarSelectionStyle: cal ?? state.calendarSelectionStyle,
          meterStyle: meter ?? state.meterStyle,
          meterColorStyle: meterColor ?? state.meterColorStyle,
          isLoaded: true,
        ),
      );
    } catch (_) {
      emit(state.copyWith(isLoaded: true));
    }
  }

  Future<void> _persist() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final payload = <String, Object?>{
        'calendarSelectionStyle': state.calendarSelectionStyle.name,
        'meterStyle': state.meterStyle.name,
        'meterColorStyle': state.meterColorStyle.name,
      };
      await prefs.setString(_prefsKey, json.encode(payload));
    } catch (_) {
      // Ignore persistence failures.
    }
  }

  static CalendarSelectionStyle? _calendarSelectionFromKey(String? key) {
    if (key == null) return null;
    for (final v in CalendarSelectionStyle.values) {
      if (v.name == key) return v;
    }
    return null;
  }

  static MeterStyle? _meterStyleFromKey(String? key) {
    if (key == null) return null;
    for (final v in MeterStyle.values) {
      if (v.name == key) return v;
    }
    return null;
  }

  static MeterColorStyle? _meterColorFromKey(String? key) {
    if (key == null) return null;
    for (final v in MeterColorStyle.values) {
      if (v.name == key) return v;
    }
    return null;
  }
}
