import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import 'app_chrome_theme.dart';
import 'app_visual_style.dart';
import '../../features/theme_customization/bloc/app_theme_state.dart';

ThemeData buildAppTheme({
  Brightness brightness = Brightness.light,
  required Color scaffoldBackgroundColor,
  required AppChromeTheme chromeTheme,
  required AppFont font,
  bool neumorphism = false,
}) {
  final baseScheme = ColorScheme.fromSeed(
    seedColor: chromeTheme.accentBlue,
    brightness: brightness,
  );

  final scheme = baseScheme.copyWith(
    primary: chromeTheme.accentBlue,
    // ignore: deprecated_member_use
    background: scaffoldBackgroundColor,
    surface: chromeTheme.surfaceColor,
    // ignore: deprecated_member_use
    onBackground: chromeTheme.textColor,
    onSurface: chromeTheme.textColor,
  );

  final baseTextTheme = switch (font) {
    AppFont.inter => GoogleFonts.interTextTheme(),
    AppFont.orbitron => GoogleFonts.orbitronTextTheme(),
  };

  final buttonShape = RoundedRectangleBorder(
    borderRadius: BorderRadius.circular(18),
  );

  ButtonStyle elevatedStyle() {
    if (!neumorphism) {
      return ElevatedButton.styleFrom(
        shape: buttonShape,
        elevation: 0,
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
      );
    }

    // Neumorphism: keep buttons the same color as the surface.
    // Depth comes from the surrounding AppCard/containers.
    return ElevatedButton.styleFrom(
      shape: buttonShape,
      elevation: 0,
      backgroundColor: scheme.surface,
      foregroundColor: scheme.primary,
      disabledBackgroundColor: scheme.surface.withOpacity(0.7),
      disabledForegroundColor: scheme.onSurface.withOpacity(0.35),
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
    ).copyWith(
      overlayColor: WidgetStateProperty.resolveWith(
        (states) => states.contains(WidgetState.pressed)
            ? scheme.primary.withOpacity(0.08)
            : null,
      ),
    );
  }

  ButtonStyle outlinedStyle() {
    final base = OutlinedButton.styleFrom(
      shape: buttonShape,
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
    );

    if (!neumorphism) return base;

    return base.copyWith(
      backgroundColor: WidgetStatePropertyAll(scheme.surface),
      side: WidgetStatePropertyAll(
        BorderSide(color: chromeTheme.mutedColor.withOpacity(0.18)),
      ),
      overlayColor: WidgetStateProperty.resolveWith(
        (states) => states.contains(WidgetState.pressed)
            ? scheme.primary.withOpacity(0.06)
            : null,
      ),
    );
  }

  return ThemeData(
    brightness: brightness,
    scaffoldBackgroundColor: scaffoldBackgroundColor,
    colorScheme: scheme,
    useMaterial3: true,
    textTheme: baseTextTheme.apply(
      bodyColor: chromeTheme.textColor,
      displayColor: chromeTheme.textColor,
    ),
    cardTheme: CardThemeData(
      color: chromeTheme.surfaceColor,
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(28),
      ),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: chromeTheme.surfaceColor,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: BorderSide(
          color: neumorphism
              ? chromeTheme.mutedColor.withOpacity(0.12)
              : chromeTheme.mutedColor.withOpacity(0.2),
        ),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: BorderSide(
          color: neumorphism
              ? chromeTheme.mutedColor.withOpacity(0.10)
              : chromeTheme.mutedColor.withOpacity(0.15),
        ),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: BorderSide(color: chromeTheme.accentBlue, width: 1.5),
      ),
      labelStyle: TextStyle(color: chromeTheme.mutedColor),
      hintStyle: TextStyle(color: chromeTheme.mutedColor.withOpacity(0.6)),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
    ),
    elevatedButtonTheme: ElevatedButtonThemeData(style: elevatedStyle()),
    filledButtonTheme: FilledButtonThemeData(style: elevatedStyle()),
    outlinedButtonTheme: OutlinedButtonThemeData(style: outlinedStyle()),
    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(
        shape: buttonShape,
        foregroundColor: scheme.primary,
      ),
    ),
    dividerTheme: DividerThemeData(
      color: chromeTheme.mutedColor.withOpacity(0.12),
      thickness: 1,
    ),
    iconTheme: IconThemeData(color: chromeTheme.textColor),
    listTileTheme: ListTileThemeData(
      tileColor: Colors.transparent,
      textColor: chromeTheme.textColor,
      iconColor: chromeTheme.mutedColor,
    ),
    extensions: [
      chromeTheme,
      AppVisualStyle(neumorphism: neumorphism),
    ],
  );
}
