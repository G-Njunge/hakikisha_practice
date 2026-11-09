import 'package:flutter/material.dart';

/// Brand palette, carried over from the web client's landing page.
abstract final class HakikishaColors {
  static const green = Color(0xFF166534);
  static const navy = Color(0xFF1A1A2E);
  static const verifiedBg = Color(0xFFDCFCE7);
  static const warning = Color(0xFF92400E);
  static const warningBg = Color(0xFFFFFBEB);
  static const danger = Color(0xFFB91C1C);
  static const dangerBg = Color(0xFFFEE2E2);
}

ThemeData buildTheme(Brightness brightness) {
  final scheme = ColorScheme.fromSeed(
    seedColor: HakikishaColors.green,
    brightness: brightness,
  );
  return ThemeData(
    colorScheme: scheme,
    useMaterial3: true,
    appBarTheme: const AppBarTheme(centerTitle: false),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        minimumSize: const Size.fromHeight(52),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        minimumSize: const Size.fromHeight(52),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    ),
    inputDecorationTheme: InputDecorationTheme(
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
    ),
    cardTheme: CardThemeData(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: scheme.outlineVariant),
      ),
    ),
  );
}
