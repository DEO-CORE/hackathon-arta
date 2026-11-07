import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_tokens.dart';
import '../../../core/ui/ui.dart';
import '../models/catalog_filter.dart';
import '../models/material_enums.dart';
import '../providers/material_providers.dart';

/// Search field and filter sheet of the buyer catalog. It only builds a
/// [CatalogFilter]; the server returns the matching page.
class BuyerCatalogFilters extends ConsumerStatefulWidget {
  const BuyerCatalogFilters({super.key});

  @override
  ConsumerState<BuyerCatalogFilters> createState() =>
      _BuyerCatalogFiltersState();
}

class _BuyerCatalogFiltersState extends ConsumerState<BuyerCatalogFilters> {
  late final TextEditingController _search;

  @override
  void initState() {
    super.initState();
    _search = TextEditingController(text: ref.read(catalogProvider).filter.q);
  }

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  void _apply(CatalogFilter f) =>
      ref.read(catalogProvider.notifier).setFilter(f);

  Future<void> _openSheet(CatalogFilter current) async {
    final result = await AppBottomSheet.show<CatalogFilter>(
      context,
      title: 'Фильтры',
      builder: (_) => _FilterForm(initial: current),
    );
    if (result != null) _apply(result);
  }

  @override
  Widget build(BuildContext context) {
    final filter = ref.watch(catalogProvider.select((s) => s.filter));
    final count = filter.activeCount;
    return Padding(
      padding: const EdgeInsets.fromLTRB(
          AppSpacing.lg, 0, AppSpacing.lg, AppSpacing.sm),
      child: AppContentColumn(
        maxWidth: 1100,
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: AppTextField(
                label: 'Поиск по названию',
                controller: _search,
                prefixIcon: Icons.search,
                textInputAction: TextInputAction.search,
                onFieldSubmitted: (v) => _apply(filter.copyWith(q: v)),
                suffix: _search.text.isEmpty
                    ? null
                    : IconButton(
                        tooltip: 'Очистить поиск',
                        icon: const Icon(Icons.close),
                        onPressed: () {
                          _search.clear();
                          _apply(filter.copyWith(q: ''));
                        },
                      ),
                onChanged: (_) => setState(() {}),
              ),
            ),
            const SizedBox(width: AppSpacing.sm),
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: AppButton(
                label: count == 0 ? 'Фильтры' : 'Фильтры ($count)',
                icon: Icons.tune,
                kind: AppButtonKind.secondary,
                onPressed: () => _openSheet(filter),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _FilterForm extends StatefulWidget {
  const _FilterForm({required this.initial});
  final CatalogFilter initial;

  @override
  State<_FilterForm> createState() => _FilterFormState();
}

class _FilterFormState extends State<_FilterForm> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _city;
  late final TextEditingController _minKg;
  late TextileType? _type;
  late MaterialCondition? _condition;
  late String _sort;

  @override
  void initState() {
    super.initState();
    _city = TextEditingController(text: widget.initial.city);
    _minKg = TextEditingController(text: widget.initial.minAvailableKg);
    _type = widget.initial.type;
    _condition = widget.initial.condition;
    _sort = widget.initial.sort;
  }

  @override
  void dispose() {
    _city.dispose();
    _minKg.dispose();
    super.dispose();
  }

  Widget _chips<T>(String title, List<T> values, T? selected,
      String Function(T) label, ValueChanged<T?> onChanged) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title, style: AppTypography.label),
        const SizedBox(height: AppSpacing.xs),
        Wrap(
          spacing: AppSpacing.sm,
          runSpacing: AppSpacing.xs,
          children: [
            for (final v in values)
              ChoiceChip(
                label: Text(label(v)),
                selected: selected == v,
                showCheckmark: true,
                onSelected: (on) => onChanged(on ? v : null),
              ),
          ],
        ),
      ],
    );
  }

  void _submit() {
    if (!_formKey.currentState!.validate()) return;
    Navigator.of(context).pop(widget.initial.copyWith(
      type: _type,
      clearType: _type == null,
      condition: _condition,
      clearCondition: _condition == null,
      city: _city.text.trim(),
      minAvailableKg: _minKg.text.trim(),
      sort: _sort,
    ));
  }

  @override
  Widget build(BuildContext context) {
    return Form(
      key: _formKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _chips<TextileType>('Тип ткани', TextileType.selectable, _type,
              (t) => t.label, (v) => setState(() => _type = v)),
          const SizedBox(height: AppSpacing.md),
          _chips<MaterialCondition>(
              'Состояние',
              MaterialCondition.selectable,
              _condition,
              (c) => c.label,
              (v) => setState(() => _condition = v)),
          const SizedBox(height: AppSpacing.md),
          _chips<String>(
              'Сортировка',
              catalogSorts.keys.toList(),
              _sort,
              (k) => catalogSorts[k]!,
              (v) => setState(() => _sort = v ?? defaultCatalogSort)),
          const SizedBox(height: AppSpacing.md),
          AppTextField(label: 'Город', controller: _city),
          const SizedBox(height: AppSpacing.md),
          AppTextField(
            label: 'Свободная масса от',
            controller: _minKg,
            suffixText: 'кг',
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            validator: validateMinKg,
          ),
          const SizedBox(height: AppSpacing.lg),
          AppButton(label: 'Применить', onPressed: _submit),
          const SizedBox(height: AppSpacing.sm),
          AppButton(
            label: 'Сбросить',
            kind: AppButtonKind.text,
            onPressed: () => Navigator.of(context).pop(widget.initial.copyWith(
              clearType: true,
              clearCondition: true,
              city: '',
              minAvailableKg: '',
            )),
          ),
        ],
      ),
    );
  }
}
