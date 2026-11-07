import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/network/api_exception.dart';
import '../../../core/session/session.dart';
import '../../../core/widgets/error_panel.dart';
import '../../auth/models/auth_models.dart';
import '../models/material_enums.dart';
import '../models/lifecycle_error.dart';
import '../models/material_models.dart';
import '../models/publish_requirements.dart';
import '../providers/material_providers.dart';
import 'material_photo.dart';
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
        loading: () => const Center(
          child: CircularProgressIndicator(semanticsLabel: 'Загрузка…'),
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
                      const SizedBox(height: 12),
                      OutlinedButton(
                        onPressed: () => context.go('/'),
                        child: const Text('На главную'),
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
            item.isOwnerView;
    final left = [
      _Header(item: item),
      const SizedBox(height: 12),
      _Photos(item: item),
      if (isOwner) ...[const SizedBox(height: 12), _Actions(item: item)],
    ];
    final right = [
      _Characteristics(item: item, isOwner: isOwner),
      const SizedBox(height: 12),
      _Balance(item: item),
      if (isOwner) ...[
        const SizedBox(height: 12),
        _AnalysisRow(item: item),
      ],
    ];
    return LayoutBuilder(builder: (context, c) {
      final wide = c.maxWidth >= 840;
      return SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Center(
          child: ConstrainedBox(
            constraints: BoxConstraints(maxWidth: wide ? 1100 : 600),
            child: wide
                ? Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                          child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: left)),
                      const SizedBox(width: 24),
                      Expanded(
                          child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: right)),
                    ],
                  )
                : Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [...left, const SizedBox(height: 12), ...right],
                  ),
          ),
        ),
      );
    });
  }
}

class _Header extends StatelessWidget {
  const _Header({required this.item});
  final MaterialItem item;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(item.name, style: Theme.of(context).textTheme.headlineSmall),
        const SizedBox(height: 8),
        MaterialStatusChip(status: item.status),
        const SizedBox(height: 4),
        Text(statusHelper(item.status)),
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
      if (item.organizationName != null) ('Продавец', item.organizationName!),
    ];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Характеристики', style: Theme.of(context).textTheme.titleMedium),
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
                  style: const TextStyle(fontWeight: FontWeight.w600)),
              TextSpan(text: r.$2),
            ])),
          ),
      ],
    );
  }
}

class _Balance extends StatelessWidget {
  const _Balance({required this.item});
  final MaterialItem item;

  @override
  Widget build(BuildContext context) {
    final b = item.balance;
    // Values come from the server as-is; the client never sums masses.
    final rows = b == null
        ? [('Свободно', item.availableKg)]
        : [
            ('Всего', b.totalKg),
            ('Свободно', b.availableKg),
            ('Удержано', b.heldKg),
            ('Передано', b.transferredKg),
            ('Использовано внутри', b.internallyUsedKg),
          ];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Масса, кг', style: Theme.of(context).textTheme.titleMedium),
        for (final r in rows)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 2),
            child: Text('${r.$1}: ${r.$2} кг'),
          ),
      ],
    );
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
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Анализ ИИ', style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: 4),
        if (item.images.isEmpty)
          const Text('Для анализа нужно фото.')
        else if (editable)
          OutlinedButton(
            onPressed: () => context.push('/materials/${item.id}/analysis'),
            child: const Text('Проанализировать фото'),
          ),
      ],
    );
  }
}

class _Actions extends ConsumerWidget {
  const _Actions({required this.item});
  final MaterialItem item;

  Future<bool> _ask(
      BuildContext context, String title, String text, String action) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(title),
        content: Text(text),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Отмена'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: Text(action),
          ),
        ],
      ),
    );
    return ok == true;
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final confirm = ref.watch(confirmMaterialProvider);
    final life = ref.watch(lifecycleProvider);
    final busy = confirm.busy || life.busy;
    final isDraft = item.status == MaterialStatus.draft;
    final canEdit = isDraft ||
        item.status == MaterialStatus.available ||
        item.status == MaterialStatus.partiallyAllocated;
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
          const SizedBox(height: 8),
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
          const SizedBox(height: 8),
        ],
        if (needsConfirm) ...[
          const Text(
              'Вы подтверждаете характеристики партии. После подтверждения они используются в подборе и плане.'),
          const SizedBox(height: 8),
          FilledButton(
            onPressed: busy
                ? null
                : () =>
                    ref.read(confirmMaterialProvider.notifier).confirm(item),
            child:
                Text(confirm.busy ? 'Отправка…' : 'Подтвердить характеристики'),
          ),
          const SizedBox(height: 8),
        ],
        if (isDraft) ...[
          if (missing.isNotEmpty) _Checklist(missing: missing),
          if (missing.isEmpty)
            FilledButton(
              onPressed: busy
                  ? null
                  : () async {
                      final ok = await _ask(
                        context,
                        'Опубликовать партию?',
                        'Партия станет видна покупателям. Масса и характеристики будут ограничены в изменении при активных заявках.',
                        'Опубликовать',
                      );
                      if (ok) {
                        await ref
                            .read(lifecycleProvider.notifier)
                            .publish(item);
                      }
                    },
              child: Text(
                  life.busy && life.lastAction == LifecycleAction.publish
                      ? 'Публикация…'
                      : 'Опубликовать'),
            ),
          const SizedBox(height: 8),
        ],
        if (canEdit)
          OutlinedButton(
            onPressed: busy
                ? null
                : () async {
                    final changed =
                        await context.push<bool>('/materials/${item.id}/edit');
                    if (changed == true) {
                      ref.invalidate(materialDetailProvider(item.id));
                    }
                  },
            child: const Text('Изменить'),
          ),
        // Offered only for a published material the server reports as fully
        // free; the server still refuses with ACTIVE_OBLIGATIONS otherwise.
        if (item.status == MaterialStatus.available ||
            item.status == MaterialStatus.partiallyAllocated ||
            item.status == MaterialStatus.completed) ...[
          const SizedBox(height: 8),
          OutlinedButton(
            onPressed: busy
                ? null
                : () async {
                    final ok = await _ask(
                      context,
                      'Архивировать партию?',
                      'Партия будет скрыта от покупателей.',
                      'Архивировать',
                    );
                    if (ok) {
                      await ref.read(lifecycleProvider.notifier).archive(item);
                    }
                  },
            child: Text(life.busy && life.lastAction == LifecycleAction.archive
                ? 'Архивация…'
                : 'Архивировать'),
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
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Чтобы опубликовать, осталось:',
            style: Theme.of(context).textTheme.titleSmall),
        for (final t in publishMissingLabels(missing))
          Padding(
            padding: const EdgeInsets.only(top: 2),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(Icons.radio_button_unchecked, size: 16),
                const SizedBox(width: 6),
                Expanded(child: Text(t)),
              ],
            ),
          ),
      ],
    );
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
            child: TextButton(
              onPressed: onRefresh,
              child: const Text('Обновить данные'),
            ),
          ),
      ],
    );
  }
}
