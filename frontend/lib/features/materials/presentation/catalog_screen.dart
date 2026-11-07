import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/session/session.dart';
import '../../../core/widgets/error_panel.dart';
import '../../auth/models/auth_models.dart';
import '../models/material_enums.dart';
import '../models/material_models.dart';
import '../providers/material_providers.dart';
import 'material_photo.dart';
import 'status_chip.dart';

class CatalogScreen extends ConsumerWidget {
  const CatalogScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isOwner =
        ref.watch(sessionProvider).user?.role == UserRole.enterprise;
    final s = ref.watch(catalogProvider);
    final ctrl = ref.read(catalogProvider.notifier);

    Future<void> create() async {
      await context.push('/materials/new');
      ctrl.reload();
    }

    Widget body;
    if (s.loading) {
      body = const Center(
        child: CircularProgressIndicator(semanticsLabel: 'Загрузка…'),
      );
    } else if (s.error != null) {
      body = Padding(
        padding: const EdgeInsets.all(16),
        child: ErrorBanner(error: s.error!, onRetry: ctrl.reload),
      );
    } else if (s.items.isEmpty) {
      body = _Empty(
        isOwner: isOwner,
        filtered: s.status != null,
        onReset: () => ctrl.setStatus(null),
        onCreate: create,
      );
    } else {
      body = _List(state: s, isOwner: isOwner);
    }

    return Scaffold(
      appBar: AppBar(title: Text(isOwner ? 'Мои партии' : 'Каталог')),
      floatingActionButton: isOwner
          ? FloatingActionButton.extended(
              onPressed: create,
              icon: const Icon(Icons.add),
              label: const Text('Создать партию'),
            )
          : null,
      body: Column(
        children: [
          if (isOwner)
            _StatusFilter(selected: s.status, onChanged: ctrl.setStatus),
          Expanded(child: body),
        ],
      ),
    );
  }
}

class _StatusFilter extends StatelessWidget {
  const _StatusFilter({required this.selected, required this.onChanged});
  final MaterialStatus? selected;
  final ValueChanged<MaterialStatus?> onChanged;

  @override
  Widget build(BuildContext context) {
    const shown = [
      MaterialStatus.draft,
      MaterialStatus.available,
      MaterialStatus.partiallyAllocated,
      MaterialStatus.reserved,
      MaterialStatus.completed,
      MaterialStatus.archived,
    ];
    return SizedBox(
      height: 56,
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        children: [
          Padding(
            padding: const EdgeInsets.only(right: 8),
            child: ChoiceChip(
              label: const Text('Все'),
              selected: selected == null,
              onSelected: (_) => onChanged(null),
            ),
          ),
          for (final st in shown)
            Padding(
              padding: const EdgeInsets.only(right: 8),
              child: ChoiceChip(
                label: Text(st.label),
                selected: selected == st,
                onSelected: (_) => onChanged(st),
              ),
            ),
        ],
      ),
    );
  }
}

class _Empty extends StatelessWidget {
  const _Empty({
    required this.isOwner,
    required this.filtered,
    required this.onReset,
    required this.onCreate,
  });
  final bool isOwner;
  final bool filtered;
  final VoidCallback onReset;
  final VoidCallback onCreate;

  @override
  Widget build(BuildContext context) {
    final text = filtered
        ? 'Ничего не найдено. Измените фильтры.'
        : isOwner
            ? 'Партий пока нет. Добавьте первую.'
            : 'Пока нет опубликованных партий.';
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(text, textAlign: TextAlign.center),
            const SizedBox(height: 16),
            if (filtered)
              OutlinedButton(
                  onPressed: onReset, child: const Text('Сбросить фильтры'))
            else if (isOwner)
              FilledButton(
                  onPressed: onCreate, child: const Text('Создать партию')),
          ],
        ),
      ),
    );
  }
}

class _List extends ConsumerWidget {
  const _List({required this.state, required this.isOwner});
  final CatalogState state;
  final bool isOwner;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ctrl = ref.read(catalogProvider.notifier);
    return LayoutBuilder(builder: (context, c) {
      final cols = c.maxWidth >= 600 ? 2 : 1;
      final rows = <List<MaterialItem>>[];
      for (var i = 0; i < state.items.length; i += cols) {
        rows.add(state.items.skip(i).take(cols).toList());
      }
      return RefreshIndicator(
        onRefresh: ctrl.reload,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(12, 4, 12, 88),
          children: [
            for (final row in rows)
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  for (var i = 0; i < cols; i++)
                    Expanded(
                      child: i < row.length
                          ? _MaterialCard(item: row[i])
                          : const SizedBox.shrink(),
                    ),
                ],
              ),
            if (state.loadMoreError != null)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: ErrorBanner(error: state.loadMoreError!),
              ),
            if (state.hasMore)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: OutlinedButton(
                  onPressed: state.loadingMore ? null : ctrl.loadMore,
                  child: Text(state.loadingMore
                      ? 'Загрузка…'
                      : state.loadMoreError != null
                          ? 'Повторить'
                          : 'Показать ещё'),
                ),
              ),
          ],
        ),
      );
    });
  }
}

class _MaterialCard extends StatelessWidget {
  const _MaterialCard({required this.item});
  final MaterialItem item;

  @override
  Widget build(BuildContext context) {
    final type = item.materialType?.label;
    final cond = item.condition?.label;
    final typeLine =
        [if (type != null) type, if (cond != null) cond].join(' · ');
    final massLine = item.status == MaterialStatus.draft
        ? 'Масса: ${item.balance?.totalKg ?? item.availableKg} кг'
        : 'Свободно: ${item.availableKg} кг';
    final price = item.pricePerKg == null
        ? 'Цена не указана'
        : '${item.pricePerKg} KGS/кг';
    final city = item.city ?? 'Город не указан';
    return Card(
      child: Semantics(
        button: true,
        label:
            'Партия ${item.name}, ${item.status.label}, свободно ${item.availableKg} кг, $city',
        excludeSemantics: true,
        child: InkWell(
          onTap: () => context.push('/materials/${item.id}'),
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                MaterialPhoto(
                  materialId: item.id,
                  imageId: item.images.isEmpty ? null : item.images.first.id,
                  label: 'Фото партии ${item.name}',
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(item.name,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: Theme.of(context).textTheme.titleMedium),
                      const SizedBox(height: 4),
                      MaterialStatusChip(status: item.status),
                      if (typeLine.isNotEmpty) Text(typeLine),
                      Text(massLine),
                      Text(city),
                      Text(price),
                      if (item.organizationName != null)
                        Text(item.organizationName!),
                    ],
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
