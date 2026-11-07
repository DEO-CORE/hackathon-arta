import 'package:flutter/material.dart';

import '../../../core/format/mass_format.dart';
import '../../../core/theme/app_tokens.dart';
import '../../../core/ui/ui.dart';
import '../models/material_models.dart';
import '../models/publish_requirements.dart';
import 'status_chip.dart';

/// Requirement keys in checklist order with their short names (the longer
/// "what to do" line comes from [publishMissingLabels]).
const _requirements = <String, String>{
  'material_type': 'Тип материала',
  'total_kg': 'Масса',
  'condition': 'Состояние',
  'city': 'Город',
  'images': 'Фото',
  'confirmation': 'Подтверждение характеристик',
};

/// Asks to publish a draft in a bottom sheet. Resolves true only when the user
/// taps "Опубликовать"; the caller then runs the unchanged publish call. The
/// button is disabled while requirements are open (the server re-checks).
Future<bool> showPublishSheet(BuildContext context, MaterialItem item) async {
  final ok = await AppBottomSheet.show<bool>(
    context,
    title: 'Опубликовать партию?',
    builder: (_) => PublishSheetContent(item: item),
  );
  return ok == true;
}

class PublishSheetContent extends StatelessWidget {
  const PublishSheetContent({super.key, required this.item});

  final MaterialItem item;

  @override
  Widget build(BuildContext context) {
    final missing = missingPublishFields(item);
    final hints = {
      for (final k in missing) k: publishMissingLabels([k]).first,
    };
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          'Партия станет видна покупателям. Масса и характеристики будут ограничены в изменении при активных заявках.',
          style: AppTypography.body.copyWith(color: AppColors.textSecondary),
        ),
        const SizedBox(height: AppSpacing.lg),
        AppKeyValueRow(
            label: 'Тип', value: item.materialType?.label ?? 'Не указан'),
        AppKeyValueRow(
            label: 'Масса',
            value: formatKg(item.balance?.totalKg ?? item.availableKg)),
        AppKeyValueRow(label: 'Город', value: item.city ?? 'Не указан'),
        AppKeyValueRow(
            label: 'Состояние', value: item.condition?.label ?? 'Не указано'),
        AppKeyValueRow(
          label: 'Статус',
          value: item.status.label,
          valueWidget: MaterialStatusChip(status: item.status),
        ),
        const SizedBox(height: AppSpacing.lg),
        AppProgressChecklist(
          title: 'Требования к публикации',
          items: [
            for (final e in _requirements.entries)
              AppChecklistItem(
                title: e.value,
                done: !missing.contains(e.key),
                subtitle: hints[e.key],
              ),
          ],
        ),
        const SizedBox(height: AppSpacing.xl),
        AppButton(
          label: 'Опубликовать',
          onPressed:
              missing.isEmpty ? () => Navigator.of(context).pop(true) : null,
        ),
        const SizedBox(height: AppSpacing.sm),
        AppButton(
          label: 'Отмена',
          kind: AppButtonKind.secondary,
          onPressed: () => Navigator.of(context).pop(false),
        ),
      ],
    );
  }
}
