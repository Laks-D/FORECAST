import 'package:flutter/material.dart';

enum AppFont {
  inter,
  orbitron,
}

class AppThemeState {
  const AppThemeState({
    required this.activeThemeId,
    required this.customThemeName,
    required this.font,
    required this.themeMode,
    required this.lightBackground,
    required this.darkBackground,
    required this.lightSurface,
    required this.darkSurface,
    required this.lightText,
    required this.darkText,
    required this.lightMuted,
    required this.darkMuted,
    required this.frameColor,
    required this.accentBlue,
  });

  final String activeThemeId;
  final String customThemeName;
  final AppFont font;

  final ThemeMode themeMode;

  /// Scaffold background when ThemeMode is light.
  final Color lightBackground;

  /// Scaffold background when ThemeMode is dark.
  final Color darkBackground;

  final Color lightSurface;
  final Color darkSurface;

  final Color lightText;
  final Color darkText;

  final Color lightMuted;
  final Color darkMuted;

  /// The "frame" color used behind the main content (the big red area today).
  final Color frameColor;

  /// Accent color used for the large blue buttons, chips, etc.
  final Color accentBlue;

  /// Base palette used for building preset states (so each preset can override
  /// only the colors it needs without inheriting from whatever the current
  /// default theme is).
  static const presetBase = AppThemeState(
    // Matte Ivory
    activeThemeId: 'matte_ivory',
    customThemeName: 'Custom',
    font: AppFont.inter,
    themeMode: ThemeMode.light,
    lightBackground: Color(0xFFF8FAFC),
    darkBackground: Color(0xFF0B0B0B),
    lightSurface: Color(0xFFFFFFFF),
    darkSurface: Color(0xFF1C1524),
    lightText: Color(0xFF111827),
    darkText: Color(0xFFEDE9FE),
    lightMuted: Color(0xFF64748B),
    darkMuted: Color(0xFFA78BFA),
    frameColor: Color(0xFFF1F5F9),
    accentBlue: Color(0xFF6D73E6),
  );

  /// App startup / reset theme.
  static const defaults = AppThemeState(
    // Default to a warm neutral palette.
    activeThemeId: 'warm_neutral',
    customThemeName: 'Custom',
    font: AppFont.inter,
    themeMode: ThemeMode.light,
    // Provided palette (light)
    lightBackground: Color(0xFFEFE9E1),
    lightSurface: Color(0xFFD9D9D9),
    lightText: Color(0xFF322D29),
    lightMuted: Color(0xFFAC9C8D),
    // Provided palette mapped to dark mode (fallback)
    darkBackground: Color(0xFF322D29),
    darkSurface: Color(0xFF322D29),
    darkText: Color(0xFFEFE9E1),
    darkMuted: Color(0xFFAC9C8D),
    frameColor: Color(0xFFD1C7BD),
    accentBlue: Color(0xFF72383D),
  );

  AppThemeState copyWith({
    String? activeThemeId,
    String? customThemeName,
    AppFont? font,
    ThemeMode? themeMode,
    Color? lightBackground,
    Color? darkBackground,
    Color? lightSurface,
    Color? darkSurface,
    Color? lightText,
    Color? darkText,
    Color? lightMuted,
    Color? darkMuted,
    Color? frameColor,
    Color? accentBlue,
  }) {
    return AppThemeState(
      activeThemeId: activeThemeId ?? this.activeThemeId,
      customThemeName: customThemeName ?? this.customThemeName,
      font: font ?? this.font,
      themeMode: themeMode ?? this.themeMode,
      lightBackground: lightBackground ?? this.lightBackground,
      darkBackground: darkBackground ?? this.darkBackground,
      lightSurface: lightSurface ?? this.lightSurface,
      darkSurface: darkSurface ?? this.darkSurface,
      lightText: lightText ?? this.lightText,
      darkText: darkText ?? this.darkText,
      lightMuted: lightMuted ?? this.lightMuted,
      darkMuted: darkMuted ?? this.darkMuted,
      frameColor: frameColor ?? this.frameColor,
      accentBlue: accentBlue ?? this.accentBlue,
    );
  }
}
