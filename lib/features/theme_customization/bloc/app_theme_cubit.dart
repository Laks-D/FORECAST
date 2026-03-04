import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import 'app_theme_state.dart';

class AppThemeCubit extends Cubit<AppThemeState> {
  AppThemeCubit() : super(AppThemeState.defaults);

  void setThemeMode(ThemeMode mode) => emit(state.copyWith(themeMode: mode));

  void setFont(AppFont font) => emit(state.copyWith(font: font));

  void setFrameColor(Color color) => emit(state.copyWith(frameColor: color));

  void setAccentBlue(Color color) => emit(state.copyWith(accentBlue: color));

  void setLightBackground(Color color) => emit(state.copyWith(lightBackground: color));

  void setDarkBackground(Color color) => emit(state.copyWith(darkBackground: color));

  void setLightSurface(Color color) => emit(state.copyWith(lightSurface: color));

  void setDarkSurface(Color color) => emit(state.copyWith(darkSurface: color));

  void setLightText(Color color) => emit(state.copyWith(lightText: color));

  void setDarkText(Color color) => emit(state.copyWith(darkText: color));

  void setLightMuted(Color color) => emit(state.copyWith(lightMuted: color));

  void setDarkMuted(Color color) => emit(state.copyWith(darkMuted: color));

  void setCustomThemeName(String name) => emit(state.copyWith(customThemeName: name, activeThemeId: 'custom'));

  void applyPreset(AppThemeState preset, {required String presetId}) {
    emit(preset.copyWith(activeThemeId: presetId));
  }

  void reset() => emit(AppThemeState.defaults);
}
