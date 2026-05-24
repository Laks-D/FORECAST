import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../core/services/user_firestore_sync.dart';
import 'app_theme_state.dart';

class AppThemeCubit extends Cubit<AppThemeState> {
  AppThemeCubit() : super(AppThemeState.defaults) {
    _authSub = FirebaseAuth.instance.authStateChanges().listen((_) => _load());
    _load();
  }

  StreamSubscription<User?>? _authSub;

  Future<void> reloadFromStorage() => _load();

  Future<void> _load() async {
    try {
      final settings = await UserFirestoreSync.instance.loadSettings();
      final raw = settings?['theme'];
      if (raw is Map<String, dynamic>) {
        emit(_fromJson(raw));
      } else if (raw is Map) {
        emit(_fromJson(Map<String, dynamic>.from(raw)));
      }
    } catch (_) {
      // Ignore load failures.
    }
  }

  Future<void> _persist(AppThemeState next) async {
    try {
      final jsonMap = _toJson(next);
      await UserFirestoreSync.instance.patchSettingsNow({'theme': jsonMap});
    } catch (_) {
      // Ignore persistence failures.
    }
  }

  void _set(AppThemeState next) {
    emit(next);
    _persist(next);
  }

  static Map<String, dynamic> _toJson(AppThemeState s) => {
        'activeThemeId': s.activeThemeId,
        'customThemeName': s.customThemeName,
        'font': s.font.name,
        'themeMode': s.themeMode.name,
        'lightBackground': s.lightBackground.value,
        'darkBackground': s.darkBackground.value,
        'lightSurface': s.lightSurface.value,
        'darkSurface': s.darkSurface.value,
        'lightText': s.lightText.value,
        'darkText': s.darkText.value,
        'lightMuted': s.lightMuted.value,
        'darkMuted': s.darkMuted.value,
        'frameColor': s.frameColor.value,
        'accentBlue': s.accentBlue.value,
      };

  static AppThemeState _fromJson(Map<String, dynamic> json) {
    AppFont parseFont(String? v) {
      for (final f in AppFont.values) {
        if (f.name == v) return f;
      }
      return AppFont.inter;
    }

    ThemeMode parseMode(String? v) {
      for (final m in ThemeMode.values) {
        if (m.name == v) return m;
      }
      return ThemeMode.system;
    }

    int colorInt(String key, int fallback) {
      final v = json[key];
      if (v is int) return v;
      if (v is num) return v.toInt();
      return fallback;
    }

    return AppThemeState(
      activeThemeId: (json['activeThemeId'] as String?) ?? AppThemeState.defaults.activeThemeId,
      customThemeName: (json['customThemeName'] as String?) ?? AppThemeState.defaults.customThemeName,
      font: parseFont(json['font'] as String?),
      themeMode: parseMode(json['themeMode'] as String?),
      lightBackground: Color(colorInt('lightBackground', AppThemeState.defaults.lightBackground.value)),
      darkBackground: Color(colorInt('darkBackground', AppThemeState.defaults.darkBackground.value)),
      lightSurface: Color(colorInt('lightSurface', AppThemeState.defaults.lightSurface.value)),
      darkSurface: Color(colorInt('darkSurface', AppThemeState.defaults.darkSurface.value)),
      lightText: Color(colorInt('lightText', AppThemeState.defaults.lightText.value)),
      darkText: Color(colorInt('darkText', AppThemeState.defaults.darkText.value)),
      lightMuted: Color(colorInt('lightMuted', AppThemeState.defaults.lightMuted.value)),
      darkMuted: Color(colorInt('darkMuted', AppThemeState.defaults.darkMuted.value)),
      frameColor: Color(colorInt('frameColor', AppThemeState.defaults.frameColor.value)),
      accentBlue: Color(colorInt('accentBlue', AppThemeState.defaults.accentBlue.value)),
    );
  }

  void setThemeMode(ThemeMode mode) => _set(state.copyWith(themeMode: mode));

  void setFont(AppFont font) => _set(state.copyWith(font: font));

  void setFrameColor(Color color) => _set(state.copyWith(frameColor: color));

  void setAccentBlue(Color color) => _set(state.copyWith(accentBlue: color));

  void setLightBackground(Color color) => _set(state.copyWith(lightBackground: color));

  void setDarkBackground(Color color) => _set(state.copyWith(darkBackground: color));

  void setLightSurface(Color color) => _set(state.copyWith(lightSurface: color));

  void setDarkSurface(Color color) => _set(state.copyWith(darkSurface: color));

  void setLightText(Color color) => _set(state.copyWith(lightText: color));

  void setDarkText(Color color) => _set(state.copyWith(darkText: color));

  void setLightMuted(Color color) => _set(state.copyWith(lightMuted: color));

  void setDarkMuted(Color color) => _set(state.copyWith(darkMuted: color));

  void setCustomThemeName(String name) => _set(state.copyWith(customThemeName: name, activeThemeId: 'custom'));

  void applyPreset(AppThemeState preset, {required String presetId}) {
    _set(preset.copyWith(activeThemeId: presetId));
  }

  void reset() => _set(AppThemeState.defaults);

  @override
  Future<void> close() async {
    await _authSub?.cancel();
    return super.close();
  }
}
