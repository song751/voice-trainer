import 'package:flutter/material.dart';

abstract final class AppTheme {
  static const _seed = Color(0xff315da8);

  static final ThemeData light = _build(Brightness.light);
  static final ThemeData dark = _build(Brightness.dark);
  static final ThemeData highContrastLight = _build(
    Brightness.light,
    highContrast: true,
  );
  static final ThemeData highContrastDark = _build(
    Brightness.dark,
    highContrast: true,
  );

  static ThemeData _build(Brightness brightness, {bool highContrast = false}) {
    final scheme = ColorScheme.fromSeed(
      seedColor: _seed,
      brightness: brightness,
      contrastLevel: highContrast ? 1 : 0,
    );
    return ThemeData(
      useMaterial3: true,
      brightness: brightness,
      colorScheme: scheme,
      scaffoldBackgroundColor: scheme.surface,
      cardTheme: CardThemeData(
        elevation: highContrast ? 0 : 1,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: highContrast
              ? BorderSide(color: scheme.outline, width: 2)
              : BorderSide.none,
        ),
      ),
      inputDecorationTheme: const InputDecorationTheme(
        border: OutlineInputBorder(),
      ),
      navigationBarTheme: const NavigationBarThemeData(height: 72),
      visualDensity: VisualDensity.standard,
    );
  }
}
