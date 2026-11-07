import 'package:flutter/material.dart';

import '../core/theme/app_tokens.dart';

export '../core/theme/app_tokens.dart';

/// Kept for existing imports.
const brandPrimary = AppColors.primary;

ThemeData buildTheme() {
  const scheme = ColorScheme(
    brightness: Brightness.light,
    primary: AppColors.primary,
    onPrimary: AppColors.onPrimary,
    primaryContainer: AppColors.primaryContainer,
    onPrimaryContainer: AppColors.onPrimaryContainer,
    secondary: AppColors.neutral,
    onSecondary: AppColors.surface,
    secondaryContainer: AppColors.neutralBg,
    onSecondaryContainer: AppColors.text,
    error: AppColors.error,
    onError: AppColors.onError,
    errorContainer: AppColors.errorBg,
    onErrorContainer: AppColors.error,
    surface: AppColors.surface,
    onSurface: AppColors.text,
    onSurfaceVariant: AppColors.textSecondary,
    outline: AppColors.controlBorder,
    outlineVariant: AppColors.border,
  );
  const minSize = Size(AppSpacing.touch, AppSpacing.touch);
  final shape = RoundedRectangleBorder(
    borderRadius: BorderRadius.circular(AppRadius.md),
  );
  OutlineInputBorder border(Color c, double w) => OutlineInputBorder(
        borderRadius: BorderRadius.circular(AppRadius.md),
        borderSide: BorderSide(color: c, width: w),
      );
  return ThemeData(
    useMaterial3: true,
    fontFamily: AppTypography.fontFamily,
    colorScheme: scheme,
    scaffoldBackgroundColor: AppColors.background,
    textTheme: AppTypography.textTheme,
    appBarTheme: AppBarTheme(
      backgroundColor: AppColors.surface,
      foregroundColor: AppColors.text,
      elevation: 0,
      scrolledUnderElevation: 0,
      shape: const Border(bottom: BorderSide(color: AppColors.border)),
      titleTextStyle: AppTypography.headlineSmall,
    ),
    dividerTheme: const DividerThemeData(color: AppColors.border),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: AppColors.surface,
      border: border(AppColors.controlBorder, 1),
      enabledBorder: border(AppColors.controlBorder, 1),
      focusedBorder: border(AppColors.focusRing, 2),
      errorBorder: border(AppColors.error, 1),
      focusedErrorBorder: border(AppColors.error, 2),
      helperStyle: AppTypography.caption,
      errorStyle: AppTypography.caption.copyWith(color: AppColors.error),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        minimumSize: const Size.fromHeight(AppSpacing.primaryHeight),
        backgroundColor: AppColors.primary,
        foregroundColor: AppColors.onPrimary,
        textStyle: AppTypography.label,
        shape: shape,
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        minimumSize: minSize,
        foregroundColor: AppColors.text,
        side: const BorderSide(color: AppColors.controlBorder),
        textStyle: AppTypography.label,
        shape: shape,
      ),
    ),
    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(
        minimumSize: minSize,
        foregroundColor: AppColors.linkText,
        textStyle: AppTypography.label,
        shape: shape,
      ),
    ),
    floatingActionButtonTheme: const FloatingActionButtonThemeData(
      backgroundColor: AppColors.primary,
      foregroundColor: AppColors.onPrimary,
    ),
    snackBarTheme: const SnackBarThemeData(behavior: SnackBarBehavior.floating),
    cardTheme: CardThemeData(
      color: AppColors.surface,
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppRadius.md),
        side: const BorderSide(color: AppColors.border),
      ),
    ),
    dialogTheme: DialogThemeData(
      backgroundColor: AppColors.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppRadius.lg),
      ),
      titleTextStyle: AppTypography.headlineSmall,
      contentTextStyle: AppTypography.body,
    ),
  );
}
