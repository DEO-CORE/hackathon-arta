import 'package:flutter/material.dart';

import '../theme/app_tokens.dart';
import 'app_hatch.dart';

class AppChecklistItem {
  const AppChecklistItem({
    required this.title,
    required this.done,
    this.subtitle,
    this.actionLabel,
    this.onAction,
  });

  final String title;
  final bool done;
  final String? subtitle;
  final String? actionLabel;
  final VoidCallback? onAction;
}

/// Hatched progress bar (solid = done, hatch = remaining), "N из M" chip and
/// rows. State is conveyed by icon and by "выполнено / не выполнено" text for
/// screen readers, not by colour.
class AppProgressChecklist extends StatelessWidget {
  const AppProgressChecklist({
    super.key,
    required this.title,
    required this.items,
  });

  final String title;
  final List<AppChecklistItem> items;

  @override
  Widget build(BuildContext context) {
    final done = items.where((i) => i.done).length;
    final total = items.length;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Expanded(
                child: Semantics(
                    header: true,
                    child: Text(title, style: AppTypography.title))),
            const SizedBox(width: AppSpacing.sm),
            DecoratedBox(
              decoration: BoxDecoration(
                color: AppColors.neutralBg,
                borderRadius: BorderRadius.circular(AppRadius.pill),
              ),
              child: Padding(
                padding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.md, vertical: AppSpacing.xs),
                child: Text('$done из $total', style: AppTypography.label),
              ),
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.md),
        _Bar(done: done, total: total),
        const SizedBox(height: AppSpacing.sm),
        for (final i in items) _Row(item: i),
      ],
    );
  }
}

class _Bar extends StatelessWidget {
  const _Bar({required this.done, required this.total});
  final int done;
  final int total;

  @override
  Widget build(BuildContext context) {
    final fraction = total == 0 ? 0.0 : done / total;
    return Semantics(
      label: 'Выполнено $done из $total',
      excludeSemantics: true,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(AppRadius.pill),
        child: SizedBox(
          height: 12,
          child: Stack(
            children: [
              const Positioned.fill(
                child: ColoredBox(
                  color: AppColors.neutralBg,
                  child: AppHatch(),
                ),
              ),
              FractionallySizedBox(
                widthFactor: fraction,
                child: const ColoredBox(
                    color: AppColors.primary, child: SizedBox.expand()),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Row extends StatelessWidget {
  const _Row({required this.item});
  final AppChecklistItem item;

  @override
  Widget build(BuildContext context) => Semantics(
        container: true,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(
                item.done ? Icons.check_circle : Icons.radio_button_unchecked,
                color: item.done ? AppColors.success : AppColors.textSecondary,
                semanticLabel: item.done ? 'выполнено' : 'не выполнено',
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(item.title, style: AppTypography.body),
                    if (item.subtitle != null)
                      Text(item.subtitle!,
                          style: AppTypography.bodySmall
                              .copyWith(color: AppColors.textSecondary)),
                  ],
                ),
              ),
              if (!item.done && item.actionLabel != null)
                TextButton(
                  onPressed: item.onAction,
                  child: Text(item.actionLabel!),
                ),
            ],
          ),
        ),
      );
}
