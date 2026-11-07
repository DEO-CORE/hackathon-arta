import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/tab_shell.dart';
import '../../../core/format/mass_format.dart';
import '../../../core/session/session.dart';
import '../../../core/theme/app_tokens.dart';
import '../../../core/ui/ui.dart';
import '../../auth/models/auth_models.dart';
import '../../auth/providers/org_context_provider.dart';
import '../../../core/session/org_context.dart';
import '../../materials/models/material_enums.dart';
import 'pending_review_screen.dart';
import '../../materials/models/material_models.dart';
import '../../materials/models/publish_requirements.dart';
import '../../materials/presentation/material_photo_card.dart';
import '../../materials/presentation/status_chip.dart';
import '../../materials/providers/material_providers.dart';
import '../../profile/providers/organization_providers.dart';

/// "A draft that still needs something" first, otherwise the first item of the
/// list as the server returned it (no client-side dates are invented).
MaterialItem? nextStepItem(List<MaterialItem> items) {
  for (final m in items) {
    if (m.status == MaterialStatus.draft &&
        missingPublishFields(m).isNotEmpty) {
      return m;
    }
  }
  return items.isEmpty ? null : items.first;
}

String initialsOf(String name) {
  final parts =
      name.trim().split(RegExp(r'\s+')).where((p) => p.isNotEmpty).toList();
  if (parts.isEmpty) return '?';
  final first = parts.first.characters.first;
  final second = parts.length > 1 ? parts[1].characters.first : '';
  return (first + second).toUpperCase();
}

/// Dashboard built from data the app already loads: the organization, and the
/// batch list from [catalogProvider]. No metrics, sums or forecasts.
class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  /// Supplier: own dashboard. Buyer and recycler: the buyer dashboard (the
  /// recycler differs only by the label). Shared modules are reused as is.
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final org = ref.watch(currentOrgContextProvider);
    if (org != null && org.isPendingReview) {
      return PendingReviewScreen(context: org);
    }
    final isSupplier = org?.isSupplier ?? false;
    final recycler = (org?.isRecycler ?? false) ||
        ref.watch(organizationProvider).valueOrNull?.activityType ==
            ActivityType.recycler;
    final canCreate = ref.watch(canProvider(Perm.materialsCreate));
    return _Dashboard(
      isEnterprise: isSupplier,
      canCreate: canCreate,
      roleLabel: isSupplier
          ? 'Предприятие'
          : recycler
              ? 'Переработчик'
              : 'Покупатель',
    );
  }
}

class _Dashboard extends ConsumerWidget {
  const _Dashboard({
    required this.isEnterprise,
    required this.canCreate,
    required this.roleLabel,
  });
  final bool isEnterprise;
  final bool canCreate;
  final String roleLabel;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(sessionProvider).user;
    final notice = ref.watch(routeNoticeProvider);
    final orgName = ref.watch(organizationProvider).valueOrNull?.name;
    final name = (orgName != null && orgName.trim().isNotEmpty)
        ? orgName
        : (user?.email ?? '');
    final catalog = ref.watch(catalogProvider);
    return AppTabShell(
      tab: AppTab.home,
      child: Scaffold(
        backgroundColor: Colors.transparent,
        // Read the padding below the shell: it includes the floating nav.
        body: Builder(
          builder: (context) => SafeArea(
            bottom: false,
            child: SingleChildScrollView(
              padding: EdgeInsets.fromLTRB(
                  AppSpacing.lg,
                  AppSpacing.sm,
                  AppSpacing.lg,
                  MediaQuery.paddingOf(context).bottom + AppSpacing.lg),
              child: AppContentColumn(
                maxWidth: 900,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _TopRow(name: name, roleLabel: roleLabel),
                    const SizedBox(height: AppSpacing.xl),
                    Text('Здравствуйте,',
                        style: AppTypography.display.copyWith(
                            fontSize: 32,
                            height: 40 / 32,
                            color: AppColors.textSecondary)),
                    Text(name,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: AppTypography.display.copyWith(
                            fontSize: 32,
                            height: 40 / 32,
                            fontWeight: FontWeight.w700)),
                    const SizedBox(height: AppSpacing.xl),
                    if (notice != null) ...[
                      _RouteNotice(
                          text: notice,
                          onClose: () => ref
                              .read(routeNoticeProvider.notifier)
                              .state = null),
                      const SizedBox(height: AppSpacing.lg),
                    ],
                    isEnterprise
                        ? _NextStepCard(
                            state: catalog,
                            isEnterprise: true,
                            canCreate: canCreate)
                        : _CatalogCard(state: catalog),
                    const SizedBox(height: AppSpacing.xl),
                    _BatchesBlock(state: catalog, isEnterprise: isEnterprise),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _TopRow extends ConsumerWidget {
  const _TopRow({required this.name, required this.roleLabel});
  final String name;
  final String roleLabel;

  @override
  Widget build(BuildContext context, WidgetRef ref) => Row(
        children: [
          Expanded(
            child: DecoratedBox(
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(AppRadius.pill),
                border: Border.all(color: AppColors.border),
              ),
              child: Padding(
                padding: const EdgeInsets.all(AppSpacing.sm),
                child: Row(
                  children: [
                    CircleAvatar(
                      backgroundColor: AppColors.primaryContainer,
                      child: Text(initialsOf(name),
                          style: AppTypography.label
                              .copyWith(color: AppColors.linkText)),
                    ),
                    const SizedBox(width: AppSpacing.md),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(name,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: AppTypography.label),
                          Text('Роль: $roleLabel',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: AppTypography.caption),
                        ],
                      ),
                    ),
                    const SizedBox(width: AppSpacing.sm),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(width: AppSpacing.md),
          AppIconTile(
            icon: Icons.menu,
            tooltip: 'Меню',
            onPressed: () => AppBottomSheet.show<void>(
              context,
              title: 'Меню',
              builder: (sheet) => Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  AppLinkCard(
                    icon: Icons.business,
                    title: 'Организация',
                    subtitle: 'Профиль и контакты',
                    onTap: () {
                      Navigator.of(sheet).pop();
                      context.go('/organization');
                    },
                  ),
                  const SizedBox(height: AppSpacing.md),
                  AppButton(
                    label: 'Выйти',
                    kind: AppButtonKind.secondary,
                    icon: Icons.logout,
                    onPressed: () {
                      Navigator.of(sheet).pop();
                      ref.read(sessionProvider.notifier).signOut();
                    },
                  ),
                ],
              ),
            ),
          ),
        ],
      );
}

class _NextStepCard extends ConsumerWidget {
  const _NextStepCard({
    required this.state,
    required this.isEnterprise,
    required this.canCreate,
  });
  final CatalogState state;
  final bool isEnterprise;
  final bool canCreate;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final Widget body;
    if (state.loading) {
      body = const Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          AppSkeleton(height: 20, width: 200),
          SizedBox(height: AppSpacing.md),
          AppSkeleton(height: 14),
          SizedBox(height: AppSpacing.lg),
          AppSkeleton(height: 52),
        ],
      );
    } else if (state.error != null) {
      body = Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(state.error!.message, style: AppTypography.body),
          const SizedBox(height: AppSpacing.md),
          AppButton(
            label: 'Повторить',
            kind: AppButtonKind.secondary,
            onPressed: () => ref.read(catalogProvider.notifier).reload(),
          ),
        ],
      );
    } else {
      final item = nextStepItem(state.items);
      if (item == null) {
        body = Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
                isEnterprise
                    ? 'Партий пока нет. Добавьте первую.'
                    : 'Пока нет опубликованных партий.',
                style: AppTypography.body),
            const SizedBox(height: AppSpacing.lg),
            if (isEnterprise && canCreate)
              AppButton(
                label: 'Создать партию',
                icon: Icons.add,
                onPressed: () => context.push('/materials/new'),
              )
            else if (!isEnterprise)
              AppButton(
                label: 'Открыть каталог',
                onPressed: () => context.push('/materials'),
              ),
          ],
        );
      } else {
        body = _NextStepBody(item: item);
      }
    }
    return DecoratedBox(
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppRadius.card),
        border: Border.all(color: AppColors.border),
        boxShadow: AppElevation.level1,
      ),
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.xl),
        child: body,
      ),
    );
  }
}

class _NextStepBody extends StatelessWidget {
  const _NextStepBody({required this.item});
  final MaterialItem item;

  @override
  Widget build(BuildContext context) {
    final missing = item.status == MaterialStatus.draft
        ? missingPublishFields(item)
        : const <String>[];
    final needsAction = item.status == MaterialStatus.draft;
    final detail = !needsAction
        ? 'Свободно: ${formatKg(item.availableKg)}'
        : missing.isEmpty
            ? 'Осталось: опубликовать'
            : 'Осталось: ${publishMissingShort(missing).join(', ')}';
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(needsAction ? 'Следующий шаг' : 'Последняя партия',
            style: AppTypography.caption),
        const SizedBox(height: AppSpacing.xs),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Text(item.name,
                  maxLines: 3,
                  overflow: TextOverflow.ellipsis,
                  style: AppTypography.headline),
            ),
            const SizedBox(width: AppSpacing.md),
            Flexible(child: MaterialStatusChip(status: item.status)),
          ],
        ),
        const SizedBox(height: AppSpacing.sm),
        Text(detail,
            style: AppTypography.body.copyWith(color: AppColors.textSecondary)),
        const SizedBox(height: AppSpacing.lg),
        AppButton(
          label: 'Открыть партию',
          icon: Icons.arrow_outward,
          onPressed: () => context.push('/materials/${item.id}'),
        ),
      ],
    );
  }
}

class _BatchesBlock extends StatelessWidget {
  const _BatchesBlock({required this.state, required this.isEnterprise});
  final CatalogState state;
  final bool isEnterprise;

  @override
  Widget build(BuildContext context) {
    final items = state.items.take(10).toList();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Expanded(
              child: Semantics(
                header: true,
                child: Text('Ваши партии',
                    style: AppTypography.headlineSmall
                        .copyWith(fontWeight: FontWeight.w700)),
              ),
            ),
            // No search in the API, so there is no search button (no stub).
            // Filters exist only in the owner's catalog.
            if (isEnterprise)
              AppIconTile(
                icon: Icons.tune,
                tooltip: 'Фильтры',
                onPressed: () => context.push('/materials'),
              ),
          ],
        ),
        const SizedBox(height: AppSpacing.md),
        if (state.loading)
          const SizedBox(
              height: 160, child: AppSkeleton(height: 160, width: 260))
        else if (items.isEmpty)
          Text(
              state.error != null
                  ? 'Партии не загружены.'
                  : 'Здесь появятся ваши партии.',
              style: AppTypography.bodySmall
                  .copyWith(color: AppColors.textSecondary))
        else
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                for (final m in items)
                  Padding(
                    padding: const EdgeInsets.only(right: AppSpacing.md),
                    child: SizedBox(
                      width: 260,
                      child: MaterialPhotoCard(
                        item: m,
                        onTap: () => context.push('/materials/${m.id}'),
                      ),
                    ),
                  ),
              ],
            ),
          ),
      ],
    );
  }
}

/// Buyer / recycler "next step": go to the catalog of published batches.
class _CatalogCard extends StatelessWidget {
  const _CatalogCard({required this.state});
  final CatalogState state;

  @override
  Widget build(BuildContext context) => DecoratedBox(
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(AppRadius.card),
          border: Border.all(color: AppColors.border),
          boxShadow: AppElevation.level1,
        ),
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.xl),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text('Каталог', style: AppTypography.caption),
              const SizedBox(height: AppSpacing.xs),
              Text('Доступные партии', style: AppTypography.headline),
              const SizedBox(height: AppSpacing.sm),
              Text(
                  state.loading
                      ? 'Загружаем каталог…'
                      : state.items.isEmpty
                          ? 'Пока нет опубликованных партий.'
                          : 'Выберите партию, чтобы посмотреть подробности.',
                  style: AppTypography.body
                      .copyWith(color: AppColors.textSecondary)),
              const SizedBox(height: AppSpacing.lg),
              AppButton(
                label: 'Открыть каталог',
                icon: Icons.arrow_outward,
                onPressed: () => context.push('/materials'),
              ),
            ],
          ),
        ),
      );
}

class _RouteNotice extends StatelessWidget {
  const _RouteNotice({required this.text, required this.onClose});
  final String text;
  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) => Semantics(
        liveRegion: true,
        container: true,
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: AppColors.warningBg,
            borderRadius: BorderRadius.circular(AppRadius.iconTile),
          ),
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.md),
            child: Row(
              children: [
                const Icon(Icons.info_outline, color: AppColors.warning),
                const SizedBox(width: AppSpacing.sm),
                Expanded(child: Text(text, style: AppTypography.bodySmall)),
                IconButton(
                  tooltip: 'Закрыть сообщение',
                  icon: const Icon(Icons.close),
                  onPressed: onClose,
                ),
              ],
            ),
          ),
        ),
      );
}
