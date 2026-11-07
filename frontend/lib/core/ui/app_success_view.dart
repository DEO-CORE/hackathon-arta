import 'package:flutter/material.dart';

import '../theme/app_tokens.dart';
import 'app_button.dart';
import 'app_key_value_row.dart';

/// Confirmation as a screen. Meaning is carried by the heading text; the check
/// circle is decorative. Never mentions payment.
class AppSuccessView extends StatelessWidget {
  const AppSuccessView({
    super.key,
    required this.title,
    required this.message,
    required this.primaryLabel,
    required this.onPrimary,
    this.secondaryLabel,
    this.onSecondary,
    this.summary = const [],
  });

  final String title;
  final String message;
  final List<(String, String)> summary;
  final String primaryLabel;
  final VoidCallback onPrimary;
  final String? secondaryLabel;
  final VoidCallback? onSecondary;

  @override
  Widget build(BuildContext context) => Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(AppSpacing.xl),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: AppSpacing.contentMax),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const ExcludeSemantics(
                  child: Center(
                    child: CircleAvatar(
                      radius: 40,
                      backgroundColor: AppColors.successBg,
                      child:
                          Icon(Icons.check, size: 40, color: AppColors.success),
                    ),
                  ),
                ),
                const SizedBox(height: AppSpacing.lg),
                Semantics(
                  liveRegion: true,
                  header: true,
                  child: Text(title,
                      textAlign: TextAlign.center,
                      style: AppTypography.headline),
                ),
                const SizedBox(height: AppSpacing.sm),
                Text(message,
                    textAlign: TextAlign.center,
                    style: AppTypography.body
                        .copyWith(color: AppColors.textSecondary)),
                if (summary.isNotEmpty) ...[
                  const SizedBox(height: AppSpacing.xl),
                  for (final r in summary)
                    AppKeyValueRow(label: r.$1, value: r.$2),
                ],
                const SizedBox(height: AppSpacing.xl),
                AppButton(label: primaryLabel, onPressed: onPrimary),
                if (secondaryLabel != null) ...[
                  const SizedBox(height: AppSpacing.sm),
                  AppButton(
                    label: secondaryLabel!,
                    kind: AppButtonKind.secondary,
                    onPressed: onSecondary,
                  ),
                ],
              ],
            ),
          ),
        ),
      );
}
