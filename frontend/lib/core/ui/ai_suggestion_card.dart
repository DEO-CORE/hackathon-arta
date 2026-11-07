import 'package:flutter/material.dart';

import '../theme/app_tokens.dart';

class AiSuggestionItem {
  const AiSuggestionItem({
    required this.label,
    required this.value,
    this.suitability,
    this.reason,
  });

  final String label;
  final String value;

  /// Words, never a number: "высокая", "средняя", "низкая", "неизвестно".
  final String? suitability;
  final String? reason;
}

class AiConfirmedEntry {
  const AiConfirmedEntry({required this.label, required this.value});
  final String label;
  final String value;
}

const aiLimitsNotice =
    'ИИ не определяет состав, вес, прочность и безопасность материала.';

/// "Предложено ИИ" block: suggested values carry a text pill, an icon, a
/// dashed-style marker and the fixed limits notice. Never styled as confirmed.
class AiSuggestionCard extends StatelessWidget {
  const AiSuggestionCard({
    super.key,
    required this.title,
    required this.items,
    this.notice = aiLimitsNotice,
  });

  final String title;
  final List<AiSuggestionItem> items;
  final String notice;

  @override
  Widget build(BuildContext context) => Semantics(
        container: true,
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(AppRadius.field),
            border: Border.all(color: AppColors.suggested),
          ),
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.lg),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Wrap(
                  spacing: AppSpacing.sm,
                  runSpacing: AppSpacing.sm,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    Text(title, style: AppTypography.title),
                    const _Pill(
                      icon: Icons.auto_awesome,
                      label: 'Предложено ИИ',
                      fg: AppColors.suggested,
                      bg: AppColors.suggestedBg,
                    ),
                  ],
                ),
                for (final i in items) ...[
                  const SizedBox(height: AppSpacing.md),
                  _Item(item: i),
                ],
                const SizedBox(height: AppSpacing.md),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Icon(Icons.info_outline,
                        size: 18, color: AppColors.textSecondary),
                    const SizedBox(width: AppSpacing.sm),
                    Expanded(child: Text(notice, style: AppTypography.caption)),
                  ],
                ),
              ],
            ),
          ),
        ),
      );
}

class _Item extends StatelessWidget {
  const _Item({required this.item});
  final AiSuggestionItem item;

  @override
  Widget build(BuildContext context) => DecoratedBox(
        decoration: const BoxDecoration(
          color: AppColors.suggestedBg,
          borderRadius: BorderRadius.all(Radius.circular(AppRadius.iconTile)),
        ),
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.md),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(item.label,
                  style: AppTypography.caption
                      .copyWith(color: AppColors.suggested)),
              Text(item.value, style: AppTypography.label),
              if (item.suitability != null)
                Text('Пригодность: ${item.suitability}',
                    style: AppTypography.bodySmall),
              if (item.reason != null)
                Text('Почему: ${item.reason}',
                    style: AppTypography.bodySmall
                        .copyWith(color: AppColors.textSecondary)),
            ],
          ),
        ),
      );
}

/// "Подтверждено вами": separate block, `success` pair, author and date.
class AiConfirmedBlock extends StatelessWidget {
  const AiConfirmedBlock({
    super.key,
    required this.entries,
    required this.authorDate,
  });

  final List<AiConfirmedEntry> entries;
  final String authorDate;

  @override
  Widget build(BuildContext context) => Semantics(
        container: true,
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: AppColors.successBg,
            borderRadius: BorderRadius.circular(AppRadius.field),
            border: Border.all(color: AppColors.success),
          ),
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.lg),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Align(
                  alignment: Alignment.centerLeft,
                  child: _Pill(
                    icon: Icons.check_circle,
                    label: 'Подтверждено вами',
                    fg: AppColors.success,
                    bg: AppColors.surface,
                  ),
                ),
                const SizedBox(height: AppSpacing.sm),
                for (final e in entries)
                  Text('${e.label}: ${e.value}', style: AppTypography.body),
                const SizedBox(height: AppSpacing.xs),
                Text(authorDate,
                    style: AppTypography.caption
                        .copyWith(color: AppColors.success)),
              ],
            ),
          ),
        ),
      );
}

class _Pill extends StatelessWidget {
  const _Pill({
    required this.icon,
    required this.label,
    required this.fg,
    required this.bg,
  });

  final IconData icon;
  final String label;
  final Color fg;
  final Color bg;

  @override
  Widget build(BuildContext context) => DecoratedBox(
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(AppRadius.pill),
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.md, vertical: AppSpacing.xs),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 16, color: fg),
              const SizedBox(width: AppSpacing.xs),
              Flexible(
                child: Text(label,
                    style: AppTypography.caption
                        .copyWith(color: fg, fontWeight: FontWeight.w500)),
              ),
            ],
          ),
        ),
      );
}
