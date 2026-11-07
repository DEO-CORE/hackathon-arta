import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/format/mass_format.dart';
import '../../../core/network/api_exception.dart';
import '../../../core/session/org_context.dart';
import '../../../core/session/session.dart';
import '../../auth/providers/org_context_provider.dart';
import '../../../core/theme/app_tokens.dart';
import '../../../core/ui/ui.dart';
import '../../../core/widgets/error_panel.dart';
import '../../auth/models/auth_models.dart';
import '../models/material_enums.dart';
import '../models/lifecycle_error.dart';
import '../models/material_models.dart';
import '../models/publish_requirements.dart';
import '../providers/material_providers.dart';
import '../../reservations/presentation/reserve_sheet.dart';
import 'material_photo.dart';
import 'publish_sheet.dart';
import 'status_chip.dart';

class MaterialDetailScreen extends ConsumerWidget {
  const MaterialDetailScreen({super.key, required this.materialId});
  final String materialId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(materialDetailProvider(materialId));
    return Scaffold(
      appBar: AppBar(title: const Text('Партия')),
      body: async.when(
        loading: () => const SingleChildScrollView(
          padding: EdgeInsets.all(AppSpacing.lg),
          child: AppContentColumn(
            child: Column(
              children: [
                AppSkeleton(height: 200),
                SizedBox(height: AppSpacing.lg),
                AppSkeletonList(count: 2),
              ],
            ),
          ),
        ),
        error: (e, _) {
          final err = e is ApiException ? e : ApiException.network();
          final gone = err.statusCode == 404 || err.statusCode == 403;
          final isBuyer =
              ref.read(sessionProvider).user?.role == UserRole.buyer;
          return Padding(
            padding: const EdgeInsets.all(16),
            child: gone
                ? Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(isBuyer && err.statusCode == 404
                          ? 'Партия больше недоступна'
                          : lifecycleErrorText(err)),
                      const SizedBox(height: AppSpacing.md),
                      AppButton(
                        kind: AppButtonKind.secondary,
                        onPressed: () => context.go('/'),
                        label: 'На главную',
                      ),
                    ],
                  )
                : ErrorBanner(
                    error: err,
                    onRetry: () =>
                        ref.invalidate(materialDetailProvider(materialId)),
                  ),
          );
        },
        data: (m) => _Body(loaded: m),
      ),
    );
  }
}

class _Body extends ConsumerWidget {
  const _Body({required this.loaded});
  final MaterialItem loaded;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // A fresher server response from publish/archive replaces the loaded card.
    final fresh = ref.watch(lifecycleProvider).item;
    final item = fresh != null &&
            fresh.id == loaded.id &&
            fresh.version >= loaded.version
        ? fresh
        : loaded;
    final isOwner =
        ref.watch(sessionProvider).user?.role == UserRole.enterprise &&
            item.isOwnerView &&
            ref.watch(canProvider(Perm.materialsEdit));
    final left = [
      _Header(item: item),
      const SizedBox(height: AppSpacing.md),
      _Photos(item: item),
      if (isOwner) ...[
        const SizedBox(height: AppSpacing.md),
        _Actions(item: item)
      ],
    ];
    final right = [
      _Characteristics(item: item, isOwner: isOwner),
      const SizedBox(height: AppSpacing.md),
      _Balance(item: item),
      if (isOwner) ...[
        const SizedBox(height: AppSpacing.md),
        _AnalysisRow(item: item),
      ],
    ];
    // Result screens (pushed with Navigator, no new GoRouter routes).
    ref.listen(lifecycleProvider, (prev, next) {
      final it = next.item;
      if (it != null &&
          next.lastAction == LifecycleAction.publish &&
          !next.busy &&
          next.error == null &&
          prev?.item?.version != it.version &&
          it.status != MaterialStatus.draft) {
        _showSuccess(context, 'Партия опубликована',
            'Теперь партию видят покупатели в каталоге.', it);
      }
    });
    ref.listen(confirmMaterialProvider, (prev, next) {
      if (next.done && !(prev?.done ?? false)) {
        _showSuccess(context, 'Характеристики подтверждены',
            'Теперь они используются в подборе и плане.', item);
      }
    });
    final primary =
        isOwner ? _primaryAction(ref, item) : _buyerAction(context, ref, item);
    return Column(
      children: [
        Expanded(
          child: LayoutBuilder(builder: (context, c) {
            final wide = c.maxWidth >= 840;
            return SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(
                  AppSpacing.lg, AppSpacing.lg, AppSpacing.lg, AppSpacing.xxl),
              child: AppContentColumn(
                maxWidth: wide ? 1100 : AppSpacing.contentMax,
                child: wide
                    ? Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                              child: Column(
                                  crossAxisAlignment:
                                      CrossAxisAlignment.stretch,
                                  children: left)),
                          const SizedBox(width: AppSpacing.xl),
                          Expanded(
                              child: Column(
                                  crossAxisAlignment:
                                      CrossAxisAlignment.stretch,
                                  children: right)),
                        ],
                      )
                    : Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          ...left,
                          const SizedBox(height: AppSpacing.md),
                          ...right
                        ],
                      ),
              ),
            );
          }),
        ),
        if (primary != null) AppBottomBar(child: primary),
      ],
    );
  }
}

void _showSuccess(
    BuildContext context, String title, String message, MaterialItem it) {
  final router = GoRouter.of(context);
  final mass = formatKg(it.balance?.totalKg ?? it.availableKg);
  Navigator.of(context).push(MaterialPageRoute<void>(
    fullscreenDialog: true,
    builder: (ctx) => AppSuccessScreen(
      title: title,
      message: message,
      summary: [
        ('Название', it.name),
        ('Статус', it.status.label),
        ('Масса', mass),
      ],
      secondaryLabel: 'К партии',
      onSecondary: () => Navigator.of(ctx).pop(),
      primaryLabel: 'К каталогу',
      onPrimary: () {
        Navigator.of(ctx).pop();
        router.go('/materials');
      },
    ),
  ));
}

class _Header extends StatelessWidget {
  const _Header({required this.item});
  final MaterialItem item;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(child: Text(item.name, style: AppTypography.headline)),
            const SizedBox(width: AppSpacing.md),
            Flexible(child: MaterialStatusChip(status: item.status)),
          ],
        ),
        const SizedBox(height: AppSpacing.xs),
        Text(statusHelper(item.status),
            style: AppTypography.bodySmall
                .copyWith(color: AppColors.textSecondary)),
      ],
    );
  }
}

class _Photos extends StatelessWidget {
  const _Photos({required this.item});
  final MaterialItem item;

  @override
  Widget build(BuildContext context) {
    if (item.images.isEmpty) {
      return const Text('У партии нет фото.');
    }
    final n = item.images.length;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Фото: $n', style: Theme.of(context).textTheme.titleSmall),
        const SizedBox(height: 8),
        SizedBox(
          height: 160,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            itemCount: n,
            separatorBuilder: (_, __) => const SizedBox(width: 8),
            itemBuilder: (_, i) => MaterialPhoto(
              materialId: item.id,
              imageId: item.images[i].id,
              label: 'Фото партии ${item.name}, ${i + 1} из $n',
              size: 160,
            ),
          ),
        ),
      ],
    );
  }
}

class _Characteristics extends StatelessWidget {
  const _Characteristics({required this.item, required this.isOwner});
  final MaterialItem item;
  final bool isOwner;

  String get _provenance {
    if (item.confirmedAt == null) return 'Не подтверждено';
    if (!item.isConfirmationCurrent) return 'Требует повторного подтверждения';
    final d = item.confirmedAt!;
    String two(int v) => v.toString().padLeft(2, '0');
    return 'Подтверждено человеком, ${two(d.day)}.${two(d.month)}.${d.year}';
  }

  @override
  Widget build(BuildContext context) {
    final rows = <(String, String)>[
      ('Тип', item.materialType?.label ?? 'Не указан'),
      ('Состояние', item.condition?.label ?? 'Не указано'),
      ('Город', item.city ?? 'Не указан'),
      ('Размер обрезков', item.scrapSize ?? 'Не указан'),
      ('Состав', item.composition ?? 'Неизвестно'),
      (
        'Цена за кг',
        item.pricePerKg == null
            ? 'Цена не указана'
            : '${item.pricePerKg} KGS/кг'
      ),
    ];
    return AppCard(
        child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Характеристики', style: AppTypography.title),
        if (isOwner)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 4),
            child: Text(_provenance,
                style: const TextStyle(fontWeight: FontWeight.w600)),
          ),
        for (final r in rows)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 2),
            child: Text.rich(TextSpan(children: [
              TextSpan(
                  text: '${r.$1}: ',
                  style: AppTypography.label
                      .copyWith(color: AppColors.textSecondary)),
              TextSpan(text: r.$2),
            ])),
          ),
      ],
    ));
  }
}

class _Balance extends StatelessWidget {
  const _Balance({required this.item});
  final MaterialItem item;

  // Segment width only: a layout weight, not a business figure.
  static double _w(String v) => double.tryParse(v) ?? 0;

  @override
  Widget build(BuildContext context) {
    final b = item.balance;
    // Values come from the server as-is; the client never sums masses.
    final free = b?.availableKg ?? item.availableKg;
    return AppCard(
        child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Масса, кг', style: AppTypography.title),
        const SizedBox(height: AppSpacing.sm),
        Text('Свободно', style: AppTypography.caption),
        Text.rich(TextSpan(children: [
          TextSpan(
              text: formatDecimal(free),
              style: AppTypography.display.copyWith(
                  fontSize: 44, height: 52 / 44, fontWeight: FontWeight.w500)),
          TextSpan(
              text: '\u00A0кг',
              style:
                  AppTypography.body.copyWith(color: AppColors.textSecondary)),
        ])),
        if (b != null) ...[
          const SizedBox(height: AppSpacing.md),
          AppMassBar(segments: [
            AppMassSegment(
                kind: AppMassKind.free,
                label: 'Свободно',
                valueText: formatKg(b.availableKg),
                weight: _w(b.availableKg)),
            AppMassSegment(
                kind: AppMassKind.reserved,
                label: 'Зарезервировано',
                valueText: formatKg(b.heldKg),
                weight: _w(b.heldKg)),
            AppMassSegment(
                kind: AppMassKind.transferred,
                label: 'Передано',
                valueText: formatKg(b.transferredKg),
                weight: _w(b.transferredKg)),
            AppMassSegment(
                kind: AppMassKind.internal,
                label: 'Использовано внутри',
                valueText: formatKg(b.internallyUsedKg),
                weight: _w(b.internallyUsedKg)),
          ]),
          Padding(
            padding: const EdgeInsets.only(top: AppSpacing.sm),
            child: Text('Всего ${formatKg(b.totalKg)}',
                style: AppTypography.caption),
          ),
        ],
      ],
    ));
  }
}

/// Entry to the AI analysis screen; needs a photo and an editable status.
class _AnalysisRow extends StatelessWidget {
  const _AnalysisRow({required this.item});
  final MaterialItem item;

  @override
  Widget build(BuildContext context) {
    final editable = item.status == MaterialStatus.draft ||
        item.status == MaterialStatus.available ||
        item.status == MaterialStatus.partiallyAllocated;
    // No empty section: nothing to show for a batch that cannot be analysed.
    if (item.images.isNotEmpty && !editable) return const SizedBox.shrink();
    return AppCard(
        child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Анализ ИИ', style: AppTypography.title),
        const SizedBox(height: 4),
        if (item.images.isEmpty)
          const Text('Для анализа нужно фото.')
        else if (editable)
          AppButton(
            kind: AppButtonKind.secondary,
            onPressed: () => context.push('/materials/${item.id}/analysis'),
            label: 'Проанализировать фото',
          ),
      ],
    ));
  }
}

bool _canEdit(MaterialItem item) =>
    item.status == MaterialStatus.draft ||
    item.status == MaterialStatus.available ||
    item.status == MaterialStatus.partiallyAllocated;

Future<bool> _ask(
    BuildContext context, String title, String text, String action,
    {bool destructive = false}) {
  return AppConfirmDialog.show(
    context,
    title: title,
    message: text,
    confirmLabel: action,
    destructive: destructive,
  );
}

/// The single next-step action, pinned in the bottom bar (null: no bar).
/// Either confirm characteristics or, once nothing is missing, publish.
Widget? _primaryAction(WidgetRef ref, MaterialItem item) {
  final confirm = ref.watch(confirmMaterialProvider);
  final life = ref.watch(lifecycleProvider);
  final busy = confirm.busy || life.busy;
  final isDraft = item.status == MaterialStatus.draft;
  final needsConfirm = !item.isConfirmationCurrent && _canEdit(item);
  if (needsConfirm) {
    return Builder(
      builder: (_) => AppButton(
        label: 'Подтвердить характеристики',
        loadingLabel: 'Отправка…',
        loading: confirm.busy,
        onPressed: busy
            ? null
            : () => ref.read(confirmMaterialProvider.notifier).confirm(item),
      ),
    );
  }
  if (isDraft &&
      missingPublishFields(item).isEmpty &&
      ref.watch(canProvider(Perm.materialsPublish))) {
    return Builder(
      builder: (context) => AppButton(
        label: 'Опубликовать',
        loadingLabel: 'Публикация…',
        loading: life.busy && life.lastAction == LifecycleAction.publish,
        onPressed: busy
            ? null
            : () async {
                final ok = await showPublishSheet(context, item);
                if (ok) {
                  await ref.read(lifecycleProvider.notifier).publish(item);
                }
              },
      ),
    );
  }
  return null;
}

/// Everything except the primary action: errors, checklist, edit, archive.
class _Actions extends ConsumerWidget {
  const _Actions({required this.item});
  final MaterialItem item;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final confirm = ref.watch(confirmMaterialProvider);
    final life = ref.watch(lifecycleProvider);
    final busy = confirm.busy || life.busy;
    final isDraft = item.status == MaterialStatus.draft;
    final canEdit = _canEdit(item);
    final needsConfirm = !item.isConfirmationCurrent && canEdit;
    final missing = missingPublishFields(item);
    void refresh() {
      ref.invalidate(confirmMaterialProvider);
      ref.read(lifecycleProvider.notifier).refresh(item.id);
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (confirm.error != null) ...[
          LifecycleErrorView(
            error: confirm.error!,
            onRefresh: refresh,
            onRetry: () =>
                ref.read(confirmMaterialProvider.notifier).confirm(item),
          ),
          const SizedBox(height: AppSpacing.sm),
        ],
        if (life.error != null) ...[
          LifecycleErrorView(
            error: life.error!,
            onRefresh: refresh,
            onRetry: () {
              final n = ref.read(lifecycleProvider.notifier);
              life.lastAction == LifecycleAction.archive
                  ? n.archive(item)
                  : n.publish(item);
            },
          ),
          const SizedBox(height: AppSpacing.sm),
        ],
        // The checklist comes before the action it explains.
        if (isDraft && missing.isNotEmpty) ...[
          _Checklist(missing: missing),
          const SizedBox(height: AppSpacing.md),
        ],
        if (needsConfirm) ...[
          const Text(
              'Вы подтверждаете характеристики партии. После подтверждения они используются в подборе и плане.'),
          const SizedBox(height: AppSpacing.sm),
        ],
        if (canEdit)
          AppButton(
            kind: AppButtonKind.secondary,
            onPressed: busy
                ? null
                : () async {
                    final changed =
                        await context.push<bool>('/materials/${item.id}/edit');
                    if (changed == true) {
                      ref.invalidate(materialDetailProvider(item.id));
                    }
                  },
            label: 'Изменить',
          ),
        // Offered only for a published material the server reports as fully
        // free; the server still refuses with ACTIVE_OBLIGATIONS otherwise.
        if (item.status == MaterialStatus.available ||
            item.status == MaterialStatus.partiallyAllocated ||
            item.status == MaterialStatus.completed) ...[
          const SizedBox(height: AppSpacing.sm),
          AppButton(
            kind: AppButtonKind.secondary,
            onPressed: busy
                ? null
                : () async {
                    final ok = await _ask(
                      context,
                      'Архивировать партию?',
                      'Партия будет скрыта от покупателей.',
                      'Архивировать',
                      destructive: true,
                    );
                    if (ok) {
                      await ref.read(lifecycleProvider.notifier).archive(item);
                    }
                  },
            label: 'Архивировать',
            loadingLabel: 'Архивация…',
            loading: life.busy && life.lastAction == LifecycleAction.archive,
          ),
        ],
      ],
    );
  }
}

class _Checklist extends StatelessWidget {
  const _Checklist({required this.missing});
  final List<String> missing;

  @override
  Widget build(BuildContext context) {
    return AppCard(
        child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Чтобы опубликовать, осталось:', style: AppTypography.title),
        for (final t in publishMissingLabels(missing))
          Padding(
            padding: const EdgeInsets.only(top: 2),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(Icons.radio_button_unchecked,
                    size: 16, color: AppColors.textSecondary),
                const SizedBox(width: 6),
                Expanded(child: Text(t)),
              ],
            ),
          ),
      ],
    ));
  }
}

/// Localized error with "Обновить данные" for version conflicts and a retry
/// for server/network failures.
class LifecycleErrorView extends StatelessWidget {
  const LifecycleErrorView({
    super.key,
    required this.error,
    required this.onRefresh,
    required this.onRetry,
  });

  final ApiException error;
  final VoidCallback onRefresh;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final conflict = error.code == 'VERSION_CONFLICT';
    final v = error.details?['current_version'];
    final text = conflict && v is int
        ? '${lifecycleErrorText(error)} Актуальная версия: $v.'
        : lifecycleErrorText(error);
    final shown = ApiException(
      code: error.code,
      message: text,
      statusCode: error.statusCode,
      requestId: error.requestId,
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        ErrorBanner(
          error: shown,
          onRetry: isRetryableServerError(error) ? onRetry : null,
        ),
        if (conflict || error.code == 'PRECONDITION_FAILED')
          Align(
            alignment: Alignment.centerRight,
            child: AppButton(
              kind: AppButtonKind.text,
              onPressed: onRefresh,
              label: 'Обновить данные',
            ),
          ),
      ],
    );
  }
}

/// Buyer side: request a reservation. Display convenience only; the server
/// re-checks permission, stock and status on POST /reservations.
Widget? _buyerAction(BuildContext context, WidgetRef ref, MaterialItem item) {
  if (item.isOwnerView || !ref.watch(canProvider(Perm.reservationCreate))) {
    return null;
  }
  final open = item.status == MaterialStatus.available ||
      item.status == MaterialStatus.partiallyAllocated;
  final free = double.tryParse(item.availableKg) ?? 0;
  if (!open || free <= 0) {
    return const Text('Свободной массы нет.', textAlign: TextAlign.center);
  }
  return AppButton(
    label: 'Запросить резерв',
    onPressed: () async {
      final created = await showReserveSheet(context, item);
      if (created) ref.invalidate(materialDetailProvider(item.id));
    },
  );
}
