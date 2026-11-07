import 'package:flutter/material.dart';

import '../theme/app_tokens.dart';
import 'app_hatch.dart';

enum AppStatKind { free, reserved, transferred }

/// One labelled plate. [value] is the server decimal string shown as-is.
class AppStatPlate extends StatelessWidget {
  const AppStatPlate({
    super.key,
    required this.kind,
    required this.label,
    required this.value,
    this.unit = 'кг',
  });

  final AppStatKind kind;
  final String label;
  final String value;
  final String unit;

  @override
  Widget build(BuildContext context) {
    final (bg, fg) = switch (kind) {
      AppStatKind.free => (AppColors.successBg, AppColors.success),
      AppStatKind.reserved => (AppColors.surface, AppColors.text),
      AppStatKind.transferred => (AppColors.neutralBg, AppColors.text),
    };
    final content = Padding(
      padding: const EdgeInsets.all(AppSpacing.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(label,
              style: AppTypography.caption.copyWith(color: fg),
              maxLines: 2,
              overflow: TextOverflow.ellipsis),
          const SizedBox(height: AppSpacing.xs),
          Text.rich(
            TextSpan(children: [
              TextSpan(
                  text: value,
                  style: AppTypography.headline
                      .copyWith(color: fg, fontWeight: FontWeight.w500)),
              TextSpan(
                  text: ' $unit',
                  style: AppTypography.bodySmall
                      .copyWith(color: AppColors.textSecondary)),
            ]),
          ),
        ],
      ),
    );
    return Semantics(
      container: true,
      label: '$label: $value $unit',
      excludeSemantics: true,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(AppRadius.field),
          border: Border.all(color: AppColors.border),
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(AppRadius.field),
          child: kind == AppStatKind.transferred
              ? AppHatch(child: content)
              : content,
        ),
      ),
    );
  }
}

/// Свободно / Зарезервировано / Передано in one row; stacked below 360 dp.
/// The client never computes these values: pass the server fields.
class AppStatTriplet extends StatelessWidget {
  const AppStatTriplet({
    super.key,
    required this.freeKg,
    required this.reservedKg,
    required this.transferredKg,
    this.totalKg,
  });

  final String freeKg;
  final String reservedKg;
  final String transferredKg;
  final String? totalKg;

  @override
  Widget build(BuildContext context) {
    final plates = [
      AppStatPlate(kind: AppStatKind.free, label: 'Свободно', value: freeKg),
      AppStatPlate(
          kind: AppStatKind.reserved,
          label: 'Зарезервировано',
          value: reservedKg),
      AppStatPlate(
          kind: AppStatKind.transferred,
          label: 'Передано',
          value: transferredKg),
    ];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        LayoutBuilder(builder: (context, c) {
          if (c.maxWidth < 360) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                for (final p in plates)
                  Padding(
                      padding: const EdgeInsets.only(bottom: AppSpacing.sm),
                      child: p),
              ],
            );
          }
          return IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                for (var i = 0; i < plates.length; i++) ...[
                  if (i > 0) const SizedBox(width: AppSpacing.sm),
                  Expanded(child: plates[i]),
                ],
              ],
            ),
          );
        }),
        if (totalKg != null)
          Padding(
            padding: const EdgeInsets.only(top: AppSpacing.sm),
            child: Text('Всего $totalKg кг', style: AppTypography.caption),
          ),
      ],
    );
  }
}
