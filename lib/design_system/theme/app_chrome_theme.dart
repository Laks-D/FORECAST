import 'package:flutter/material.dart';

@immutable
class AppChromeTheme extends ThemeExtension<AppChromeTheme> {
  const AppChromeTheme({
    required this.frameColor,
    required this.accentBlue,
    required this.surfaceColor,
    required this.textColor,
    required this.mutedColor,
  });

  static const fallback = AppChromeTheme(
    frameColor: Color(0xFFE32626),
    accentBlue: Color(0xFF4F86B7),
    surfaceColor: Color(0xFFFFFFFF),
    textColor: Color(0xFF111827),
    mutedColor: Color(0xFF6B7280),
  );

  final Color frameColor;
  final Color accentBlue;
  final Color surfaceColor;
  final Color textColor;
  final Color mutedColor;

  static AppChromeTheme of(BuildContext context) {
    return Theme.of(context).extension<AppChromeTheme>() ?? fallback;
  }

  @override
  AppChromeTheme copyWith({
    Color? frameColor,
    Color? accentBlue,
    Color? surfaceColor,
    Color? textColor,
    Color? mutedColor,
  }) {
    return AppChromeTheme(
      frameColor: frameColor ?? this.frameColor,
      accentBlue: accentBlue ?? this.accentBlue,
      surfaceColor: surfaceColor ?? this.surfaceColor,
      textColor: textColor ?? this.textColor,
      mutedColor: mutedColor ?? this.mutedColor,
    );
  }

  @override
  AppChromeTheme lerp(ThemeExtension<AppChromeTheme>? other, double t) {
    if (other is! AppChromeTheme) return this;

    return AppChromeTheme(
      frameColor: Color.lerp(frameColor, other.frameColor, t) ?? frameColor,
      accentBlue: Color.lerp(accentBlue, other.accentBlue, t) ?? accentBlue,
      surfaceColor: Color.lerp(surfaceColor, other.surfaceColor, t) ?? surfaceColor,
      textColor: Color.lerp(textColor, other.textColor, t) ?? textColor,
      mutedColor: Color.lerp(mutedColor, other.mutedColor, t) ?? mutedColor,
    );
  }
}
