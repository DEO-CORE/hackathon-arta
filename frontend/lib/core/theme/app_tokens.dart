import 'package:flutter/material.dart';

/// Colour tokens. Orange is a fill colour only: text on it is [text], and
/// orange text or links on light surfaces use [linkText] (contrast).
abstract final class AppColors {
  static const primary = Color(0xFFF08331);
  static const onPrimary = Color(0xFF17191D);
  static const primaryContainer = Color(0xFFFFF1E6);
  static const onPrimaryContainer = Color(0xFF17191D);
  static const linkText = Color(0xFFB04A00);

  static const text = Color(0xFF17191D);
  static const textSecondary = Color(0xFF5B6270);
  static const background = Color(0xFFF7F8FA);
  static const surface = Color(0xFFFFFFFF);
  static const border = Color(0xFFE6E8EC);
  static const surfaceSunken = Color(0xFFEEF0F3);

  /// Control boundary needs 3:1 against the surface; [border] is decorative.
  static const controlBorder = Color(0xFF7F8691);
  static const focusRing = Color(0xFF17191D);

  static const error = Color(0xFFB3261E);
  static const onError = Color(0xFFFFFFFF);
  static const errorBg = Color(0xFFFCE4E1);
  static const success = Color(0xFF1B6B3A);
  static const successBg = Color(0xFFDDF3E4);
  static const warning = Color(0xFF7A4A00);
  static const warningBg = Color(0xFFFFF0CC);
  static const suggested = Color(0xFF3B4BA0);
  static const suggestedBg = Color(0xFFE6E9F8);
  static const neutral = Color(0xFF5B6270);
  static const neutralBg = Color(0xFFEEF0F3);
  static const demoBanner = Color(0xFF333333);

  /// Redesign tokens (phase B). Semi-opaque fills instead of blur.
  static const backgroundWash = primaryContainer;
  static const navSurface = Color(0xF0FFFFFF);
  static const overlaySurface = Color(0xEBFFFFFF);
  static const hatch = Color(0x66737B88);
  static const navDark = Color(0xFF1C1F24);
  static const navDarkTile = Color(0xFF2B2F36);
  static const onNavDark = Color(0xFFE8EAED);

  /// Peach top wash of the auth screens.
  static const authWash = Color(0xFFFBD9BF);
}

abstract final class AppSpacing {
  static const double xs = 4;
  static const double sm = 8;
  static const double md = 12;
  static const double lg = 16;
  static const double xl = 24;
  static const double xxl = 32;

  /// Minimum touch target.
  static const double touch = 48;

  /// Full-width primary action height.
  static const double primaryHeight = 52;

  /// Bottom padding so a FAB never covers the last list item.
  static const double listBottomFab = 96;

  /// Content column width on wide windows.
  static const double contentMax = 560;
}

abstract final class AppRadius {
  static const double sm = 8;
  static const double md = 12;
  static const double lg = 16;
  static const double pill = 999;
  static const double field = 20;
  static const double iconTile = 16;
  static const double card = 28;
}

abstract final class AppElevation {
  static const List<BoxShadow> none = [];
  static const List<BoxShadow> level1 = [
    BoxShadow(color: Color(0x0F17191D), blurRadius: 3, offset: Offset(0, 1)),
  ];
  static const List<BoxShadow> level2 = [
    BoxShadow(color: Color(0x1417191D), blurRadius: 8, offset: Offset(0, 2)),
  ];
  static const List<BoxShadow> level3 = [
    BoxShadow(color: Color(0x1A17191D), blurRadius: 16, offset: Offset(0, 6)),
  ];
}

abstract final class AppTypography {
  static const fontFamily = 'Roboto';

  static TextStyle _s(double size, double height, FontWeight w) => TextStyle(
        fontFamily: fontFamily,
        fontSize: size,
        height: height / size,
        fontWeight: w,
        color: AppColors.text,
      );

  static final display = _s(36, 44, FontWeight.w400);
  static final headline = _s(24, 32, FontWeight.w500);
  static final headlineSmall = _s(20, 28, FontWeight.w500);
  static final title = _s(16, 24, FontWeight.w500);
  static final body = _s(16, 24, FontWeight.w400);
  static final bodySmall = _s(14, 20, FontWeight.w400);
  static final label = _s(14, 20, FontWeight.w500);
  static final caption =
      _s(12, 16, FontWeight.w400).copyWith(color: AppColors.textSecondary);

  static TextTheme get textTheme => TextTheme(
        displaySmall: display,
        headlineMedium: headline,
        headlineSmall: headline,
        titleLarge: headlineSmall,
        titleMedium: title,
        titleSmall: label,
        bodyLarge: body,
        bodyMedium: bodySmall,
        bodySmall: caption,
        labelLarge: label,
        labelMedium: caption.copyWith(fontWeight: FontWeight.w500),
        labelSmall: caption,
      );
}
