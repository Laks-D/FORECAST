import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import 'app_chrome_theme.dart';
import '../../features/theme_customization/bloc/app_theme_state.dart';

ThemeData buildAppTheme({
  Brightness brightness = Brightness.light,
  required Color scaffoldBackgroundColor,
  required AppChromeTheme chromeTheme,
  required AppFont font,
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

  return ThemeData(
    brightness: brightness,
    scaffoldBackgroundColor: scaffoldBackgroundColor,
    colorScheme: scheme,
    useMaterial3: true,
    textTheme: baseTextTheme.apply(
      bodyColor: chromeTheme.textColor,
      displayColor: chromeTheme.textColor,
    ),
    extensions: <ThemeExtension<dynamic>>[
      chromeTheme,
    ],
  );
}
