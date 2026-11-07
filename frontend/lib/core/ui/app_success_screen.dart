import 'package:flutter/material.dart';

import '../theme/app_tokens.dart';
import 'app_button.dart';
import 'app_key_value_row.dart';
import 'app_layout.dart';
import 'app_shell.dart';
import 'app_top_bar.dart';

/// Full-screen result: green check circle, result heading, one line, summary
/// card and a pinned pair "secondary / primary". No payment wording.
class AppSuccessScreen extends StatelessWidget {
  const AppSuccessScreen({
    super.key,
    required this.title,
    required this.message,
    required this.summary,
    required this.secondaryLabel,
    required this.onSecondary,
    required this.primaryLabel,
    required this.onPrimary,
  });

  final String title;
  final String message;
  final List<(String, String)> summary;
  final String secondaryLabel;
  final VoidCallback onSecondary;
  final String primaryLabel;
  final VoidCallback onPrimary;

  @override
  Widget build(BuildContext context) {
    final secondary = AppButton(
        label: secondaryLabel,
        kind: AppButtonKind.secondary,
        onPressed: onSecondary);
    final primary = AppButton(label: primaryLabel, onPressed: onPrimary);
    // Stacked when text is large; side by side otherwise.
    final stacked = MediaQuery.textScalerOf(context).scale(16) > 22;
    return AppBackground(
      child: Scaffold(
        backgroundColor: Colors.transparent,
        appBar: AppTopBar(
            showBack: false,
            trailing: AppIconTile(
                icon: Icons.close, tooltip: 'Закрыть', onPressed: onSecondary)),
        bottomNavigationBar: AppBottomBar(
          child: stacked
              ? Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    primary,
                    const SizedBox(height: AppSpacing.sm),
                    secondary
                  ],
                )
              : Row(
                  children: [
                    Expanded(child: secondary),
                    const SizedBox(width: AppSpacing.md),
                    Expanded(child: primary),
                  ],
                ),
        ),
        body: SingleChildScrollView(
          padding: const EdgeInsets.all(AppSpacing.xl),
          child: AppContentColumn(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const ExcludeSemantics(
                  child: Center(
                    child: CircleAvatar(
                      radius: 32,
                      backgroundColor: AppColors.successBg,
                      child:
                          Icon(Icons.check, size: 36, color: AppColors.success),
                    ),
                  ),
                ),
                const SizedBox(height: AppSpacing.lg),
                Semantics(
                  liveRegion: true,
                  header: true,
                  child: Text(title,
                      textAlign: TextAlign.center,
                      style: AppTypography.headline.copyWith(fontSize: 28)),
                ),
                const SizedBox(height: AppSpacing.sm),
                Text(message,
                    textAlign: TextAlign.center,
                    style: AppTypography.body
                        .copyWith(color: AppColors.textSecondary)),
                const SizedBox(height: AppSpacing.xl),
                DecoratedBox(
                  decoration: BoxDecoration(
                    color: AppColors.surface,
                    borderRadius: BorderRadius.circular(AppRadius.card),
                    border: Border.all(color: AppColors.border),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                        horizontal: AppSpacing.lg, vertical: AppSpacing.sm),
                    child: Column(
                      children: [
                        for (final r in summary)
                          AppKeyValueRow(label: r.$1, value: r.$2),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
