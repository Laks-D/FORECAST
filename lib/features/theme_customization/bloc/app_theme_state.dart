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
    activeThemeId: 'dark_fintech',
    customThemeName: 'Custom',
    font: AppFont.inter,
    themeMode: ThemeMode.dark,
    lightBackground: Color(0xFFF0F4F8),
    darkBackground: Color(0xFF0B0B0C),
    lightSurface: Color(0xFFFFFFFF),
    darkSurface: Color(0xFF1A1B1E),
    lightText: Color(0xFF111827),
    darkText: Color(0xFFF5F5F5),
    lightMuted: Color(0xFF6B7280),
    darkMuted: Color(0xFF9CA3AF),
    frameColor: Color(0xFF0B0B0C),
    accentBlue: Color(0xFFA8DEC5),
  );

  static const defaults = AppThemeState(
    activeThemeId: 'dark_fintech',
    customThemeName: 'Custom',
    font: AppFont.inter,
    themeMode: ThemeMode.dark,
    lightBackground: Color(0xFFF0F4F8),
    lightSurface: Color(0xFFFFFFFF),
    lightText: Color(0xFF111827),
    lightMuted: Color(0xFF6B7280),
    darkBackground: Color(0xFF0B0B0C),
    darkSurface: Color(0xFF1A1B1E),
    darkText: Color(0xFFF5F5F5),
    darkMuted: Color(0xFF9CA3AF),
    frameColor: Color(0xFF0B0B0C),
    accentBlue: Color(0xFFA8DEC5),
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
