import 'package:flutter/material.dart';

import '../theme/app_tokens.dart';

/// Label left, value right-aligned, hairline below. Wraps instead of clipping.
class AppKeyValueRow extends StatelessWidget {
  const AppKeyValueRow({super.key, required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) => Semantics(
        container: true,
        label: '$label: $value',
        excludeSemantics: true,
        child: DecoratedBox(
          decoration: const BoxDecoration(
            border: Border(bottom: BorderSide(color: AppColors.border)),
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: AppSpacing.md),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  flex: 2,
                  child: Text(label,
                      style: AppTypography.bodySmall
                          .copyWith(color: AppColors.textSecondary)),
                ),
                const SizedBox(width: AppSpacing.md),
                Expanded(
                  flex: 3,
                  child: Text(value,
                      textAlign: TextAlign.end, style: AppTypography.body),
                ),
              ],
            ),
          ),
        ),
      );
}

/// Tappable card: icon tile, title, grey sub-line and an arrow.
class AppLinkCard extends StatelessWidget {
  const AppLinkCard({
    super.key,
    required this.icon,
    required this.title,
    required this.onTap,
    this.subtitle,
  });

  final IconData icon;
  final String title;
  final String? subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Semantics(
        button: true,
        label: subtitle == null ? title : '$title. $subtitle',
        excludeSemantics: true,
        child: Material(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(AppRadius.field),
          child: InkWell(
            borderRadius: BorderRadius.circular(AppRadius.field),
            onTap: onTap,
            child: Ink(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(AppRadius.field),
                border: Border.all(color: AppColors.border),
              ),
              padding: const EdgeInsets.all(AppSpacing.lg),
              child: Row(
                children: [
                  CircleAvatar(
                    backgroundColor: AppColors.primaryContainer,
                    child: Icon(icon, color: AppColors.linkText),
                  ),
                  const SizedBox(width: AppSpacing.md),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(title, style: AppTypography.title),
                        if (subtitle != null)
                          Text(subtitle!,
                              style: AppTypography.bodySmall
                                  .copyWith(color: AppColors.textSecondary)),
                      ],
                    ),
                  ),
                  const Icon(Icons.arrow_outward),
                ],
              ),
            ),
          ),
        ),
      );
}
