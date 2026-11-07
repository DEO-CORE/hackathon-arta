import 'package:flutter/material.dart';

import '../../../core/theme/app_tokens.dart';
import '../../../core/ui/app_text_field.dart';
import '../models/material_enums.dart';
import '../models/material_rules.dart';
import 'material_form_model.dart';

/// Shared field set. [fieldErrors] are server 422 messages keyed by JSON field;
/// [lockedFields] are blocked by ACTIVE_OBLIGATIONS.
class MaterialFormFields extends StatelessWidget {
  const MaterialFormFields({
    super.key,
    required this.model,
    required this.enabled,
    this.fieldErrors = const {},
    this.requireAll = true,
  });

  final MaterialFormModel model;
  final bool enabled;
  final Map<String, String> fieldErrors;
  final bool requireAll;

  @override
  Widget build(BuildContext context) {
    const gap = SizedBox(height: AppSpacing.lg);
    return ListenableBuilder(
      listenable: model,
      builder: (context, _) => Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          AppTextField(
            controller: model.name,
            enabled: enabled,
            textInputAction: TextInputAction.next,
            autovalidateMode: AutovalidateMode.onUserInteraction,
            label: 'Название (обязательно)',
            errorText: fieldErrors['name'],
            validator: (v) => validateRequiredText(v,
                emptyMessage: 'Укажите название партии.'),
          ),
          gap,
          DropdownButtonFormField<TextileType>(
            initialValue: model.type,
            isExpanded: true,
            autovalidateMode: AutovalidateMode.onUserInteraction,
            decoration: InputDecoration(
              labelText: 'Тип материала',
              errorText: fieldErrors['material_type'],
            ),
            items: [
              for (final t in TextileType.selectable)
                DropdownMenuItem(value: t, child: Text(t.label)),
            ],
            onChanged: enabled ? (v) => model.type = v : null,
            validator: (v) =>
                requireAll && v == null ? 'Выберите тип материала.' : null,
          ),
          gap,
          DropdownButtonFormField<MaterialCondition>(
            initialValue: model.condition,
            isExpanded: true,
            autovalidateMode: AutovalidateMode.onUserInteraction,
            decoration: InputDecoration(
              labelText: 'Состояние',
              errorText: fieldErrors['condition'],
            ),
            items: [
              for (final c in MaterialCondition.selectable)
                DropdownMenuItem(value: c, child: Text(c.label)),
            ],
            onChanged: enabled ? (v) => model.condition = v : null,
            validator: (v) =>
                requireAll && v == null ? 'Выберите состояние.' : null,
          ),
          gap,
          AppTextField(
            controller: model.mass,
            enabled: enabled,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            textInputAction: TextInputAction.next,
            autovalidateMode: AutovalidateMode.onUserInteraction,
            label: 'Масса',
            suffixText: 'кг',
            helper: 'Укажите массу в килограммах, например 12,5.',
            errorText: fieldErrors['total_kg'],
            validator: validateDraftMassKg,
          ),
          gap,
          AppTextField(
            controller: model.city,
            enabled: enabled,
            textInputAction: TextInputAction.next,
            autovalidateMode: AutovalidateMode.onUserInteraction,
            label: 'Город',
            errorText: fieldErrors['city'],
            validator: (v) => requireAll
                ? validateRequiredText(v,
                    emptyMessage: 'Укажите город.', max: 100)
                : null,
          ),
          gap,
          AppTextField(
            controller: model.scrapSize,
            enabled: enabled,
            textInputAction: TextInputAction.next,
            autovalidateMode: AutovalidateMode.onUserInteraction,
            label: 'Размер обрезков (необязательно)',
            errorText: fieldErrors['scrap_size'],
            validator: (v) => validateOptionalText(v, max: 100),
          ),
          gap,
          AppTextField(
            controller: model.composition,
            enabled: enabled,
            textInputAction: TextInputAction.next,
            autovalidateMode: AutovalidateMode.onUserInteraction,
            label: 'Состав (необязательно)',
            helper: 'Если состав неизвестен, оставьте пустым.',
            errorText: fieldErrors['composition'],
            validator: (v) => validateOptionalText(v),
          ),
          gap,
          AppTextField(
            controller: model.price,
            enabled: enabled,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            autovalidateMode: AutovalidateMode.onUserInteraction,
            label: 'Цена за кг (необязательно)',
            suffixText: 'KGS/кг',
            helper: 'Оставьте пустым, если цена не определена.',
            errorText: fieldErrors['price_per_kg'],
            validator: validatePriceKgs,
          ),
        ],
      ),
    );
  }
}
