import 'package:flutter/material.dart';

/// Brand primary from the task brief; other tokens await docs/design/tokens.md values.
const brandPrimary = Color(0xFFF08331);

ThemeData buildTheme() {
  final scheme = ColorScheme.fromSeed(seedColor: brandPrimary).copyWith(
    primary: brandPrimary,
    // White on #F08331 is below WCAG AA for text; dark text is used instead.
    onPrimary: const Color(0xFF1A1A1A),
  );
  return ThemeData(
    useMaterial3: true,
    colorScheme: scheme,
    inputDecorationTheme: const InputDecorationTheme(
      border: OutlineInputBorder(),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(48)),
    ),
  );
}
