import 'package:flutter/material.dart';

import '../theme/app_tokens.dart';

enum AppTone { neutral, success, warning, error, accent, suggested }

/// Pill with tone, icon and text: meaning never relies on colour alone.
/// [dashed] is a non-colour cue for AI suggestions.
class AppStatusBadge extends StatelessWidget {
  const AppStatusBadge({
    super.key,
    required this.label,
    required this.icon,
    this.tone = AppTone.neutral,
    this.semanticsLabel,
    this.outlined = false,
  });

  final String label;
  final IconData icon;
  final AppTone tone;
  final String? semanticsLabel;
  final bool outlined;

  static (Color, Color) colors(AppTone t) => switch (t) {
        AppTone.neutral => (AppColors.neutral, AppColors.neutralBg),
        AppTone.success => (AppColors.success, AppColors.successBg),
        AppTone.warning => (AppColors.warning, AppColors.warningBg),
        AppTone.error => (AppColors.error, AppColors.errorBg),
        AppTone.accent => (
            AppColors.onPrimaryContainer,
            AppColors.primaryContainer
          ),
        AppTone.suggested => (AppColors.suggested, AppColors.suggestedBg),
      };

  @override
  Widget build(BuildContext context) {
    final (fg, bg) = colors(tone);
    return Semantics(
      label: semanticsLabel ?? label,
      excludeSemantics: true,
      child: Container(
        padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.md - 2, vertical: AppSpacing.xs + 2),
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(AppRadius.pill),
          border: outlined ? Border.all(color: fg) : null,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 16, color: fg),
            const SizedBox(width: AppSpacing.xs + 2),
            Flexible(
              child: Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: AppTypography.caption
                    .copyWith(color: fg, fontWeight: FontWeight.w500),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
