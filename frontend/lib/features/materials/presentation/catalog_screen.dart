import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/tab_shell.dart';
import '../../../core/session/session.dart';
import '../../../core/theme/app_tokens.dart';
import '../../../core/ui/ui.dart';
import '../../../core/widgets/error_panel.dart';
import '../../auth/models/auth_models.dart';
import '../models/material_enums.dart';
import '../models/material_models.dart';
import '../providers/material_providers.dart';
import 'material_photo_card.dart';

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
      body = const SingleChildScrollView(
        padding: EdgeInsets.all(AppSpacing.lg),
        child: AppSkeletonList(),
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
      body = const SizedBox.shrink(); // replaced by the list below
    }

    return AppTabShell(
      tab: AppTab.materials,
      child: Scaffold(
        backgroundColor: Colors.transparent,
        appBar: AppTopBar(
          title: isOwner ? 'Мои партии' : 'Каталог',
          onBack: tabBack(context),
        ),
        body: Builder(builder: (context) {
          final header = Column(
            children: [
              if (isOwner)
                Padding(
                  padding: const EdgeInsets.fromLTRB(
                      AppSpacing.lg, 0, AppSpacing.lg, AppSpacing.sm),
                  child: AppContentColumn(
                    child: Align(
                      alignment: Alignment.centerRight,
                      // "Создать" (not "Создать партию") so the label is not
                      // duplicated with the empty-state button.
                      child: SizedBox(
                        width: 168,
                        child: AppButton(
                          label: 'Создать',
                          icon: Icons.add,
                          onPressed: create,
                        ),
                      ),
                    ),
                  ),
                ),
              if (isOwner)
                _StatusFilter(selected: s.status, onChanged: ctrl.setStatus),
            ],
          );
          // In the list state the header scrolls with the cards, so large
          // text sizes never squeeze the list into a few pixels.
          if (!s.loading && s.error == null && s.items.isNotEmpty) {
            return _List(state: s, isOwner: isOwner, header: header);
          }
          return Column(children: [header, Expanded(child: body)]);
        }),
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
    // Wrap (not a horizontal scroller): long labels such as "Частично
    // распределено" are never cut off and nothing is hidden off-screen.
    Widget chip(String label, bool selected, VoidCallback onTap) => ChoiceChip(
          label: Text(label),
          selected: selected,
          showCheckmark: true,
          shape: const StadiumBorder(),
          side: const BorderSide(color: AppColors.controlBorder),
          selectedColor: AppColors.primaryContainer,
          backgroundColor: AppColors.surface,
          onSelected: (_) => onTap(),
        );
    return Padding(
      padding: const EdgeInsets.fromLTRB(
          AppSpacing.lg, 0, AppSpacing.lg, AppSpacing.sm),
      child: AppContentColumn(
        maxWidth: 1100,
        child: Align(
          alignment: Alignment.centerLeft,
          child: Wrap(
            spacing: AppSpacing.sm,
            runSpacing: AppSpacing.xs,
            children: [
              chip('Все', selected == null, () => onChanged(null)),
              for (final st in shown)
                chip(st.label, selected == st, () => onChanged(st)),
            ],
          ),
        ),
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
              AppButton(
                  kind: AppButtonKind.secondary,
                  onPressed: onReset,
                  label: 'Сбросить фильтры')
            else if (isOwner)
              AppButton(onPressed: onCreate, label: 'Создать партию'),
          ],
        ),
      ),
    );
  }
}

class _List extends ConsumerWidget {
  const _List(
      {required this.state, required this.isOwner, required this.header});
  final Widget header;
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
          // Bottom: the floating nav inset (from the shell) plus a margin.
          padding: EdgeInsets.fromLTRB(
              AppSpacing.lg,
              AppSpacing.xs,
              AppSpacing.lg,
              MediaQuery.paddingOf(context).bottom + AppSpacing.lg),
          children: [
            header,
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
                child: AppButton(
                  kind: AppButtonKind.secondary,
                  onPressed: state.loadingMore ? null : ctrl.loadMore,
                  label: state.loadingMore
                      ? 'Загрузка…'
                      : state.loadMoreError != null
                          ? 'Повторить'
                          : 'Показать ещё',
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
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(bottom: AppSpacing.md),
        child: MaterialPhotoCard(
          item: item,
          onTap: () => context.push('/materials/${item.id}'),
        ),
      );
}
