import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/format/mass_format.dart';
import '../../../core/theme/app_tokens.dart';
import '../../../core/ui/ui.dart';
import '../../../core/config/app_config.dart';
import '../../../core/network/api_exception.dart';
import '../../../core/session/session.dart';
import '../../../core/widgets/error_panel.dart';
import '../../auth/models/auth_models.dart';
import '../../materials/models/material_enums.dart';
import '../../materials/models/material_models.dart';
import '../../materials/presentation/material_detail_screen.dart'
    show LifecycleErrorView;
import '../../materials/providers/material_providers.dart';
import '../models/analysis_models.dart';
import '../providers/analysis_providers.dart';

const analysisNotice =
    'ИИ оценивает только внешний вид по фото: цвет, рисунок, предполагаемую фактуру. Он не определяет состав, вес, прочность и безопасность материала. Эти данные указывает и подтверждает человек.';

/// Statuses in which characteristics may still be edited and confirmed
/// (api.md 19.5).
bool canEditMaterial(MaterialItem m) =>
    m.status == MaterialStatus.draft ||
    m.status == MaterialStatus.available ||
    m.status == MaterialStatus.partiallyAllocated;

class AnalysisScreen extends ConsumerWidget {
  const AnalysisScreen({super.key, required this.materialId});
  final String materialId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final material = ref.watch(materialDetailProvider(materialId));
    return Scaffold(
      appBar: AppBar(title: const Text('Анализ ИИ')),
      body: material.when(
        loading: () => const SingleChildScrollView(
          padding: EdgeInsets.all(AppSpacing.lg),
          child: AppSkeletonList(count: 3),
        ),
        error: (e, _) => Padding(
          padding: const EdgeInsets.all(16),
          child: ErrorBanner(
            error: e is ApiException ? e : ApiException.network(),
            onRetry: () => ref.invalidate(materialDetailProvider(materialId)),
          ),
        ),
        data: (m) {
          final isOwner =
              ref.watch(sessionProvider).user?.role == UserRole.enterprise &&
                  m.isOwnerView;
          if (!isOwner) {
            return const Padding(
              padding: EdgeInsets.all(16),
              child: Text('Анализ доступен только владельцу партии.'),
            );
          }
          return _Body(material: m);
        },
      ),
    );
  }
}

class _Body extends ConsumerWidget {
  const _Body({required this.material});
  final MaterialItem material;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = ref.watch(analysisControllerProvider(material.id));
    final demoBuild = ref.watch(appConfigProvider).useDemoData;
    final a = s.analysis;
    final simulation = demoBuild || (a?.isSimulation ?? false);
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(
          AppSpacing.lg, AppSpacing.lg, AppSpacing.lg, AppSpacing.xxl),
      child: Align(
        alignment: Alignment.topCenter,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 640),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _Plate(simulation: simulation, fallback: a?.isFallback ?? false),
              const SizedBox(height: 8),
              const Text(analysisNotice),
              const SizedBox(height: 16),
              _AnalysisPart(
                  material: material, state: s, simulation: simulation),
              const SizedBox(height: 24),
              _HumanBlock(material: material),
            ],
          ),
        ),
      ),
    );
  }
}

class _Plate extends StatelessWidget {
  const _Plate({required this.simulation, required this.fallback});
  final bool simulation;
  final bool fallback;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final title = simulation ? 'Симуляция' : 'ИИ-результат, требует проверки';
    final lines = <String>[
      if (simulation) 'Демо: смоделированный результат.',
      if (simulation) 'Это пример результата, а не ответ реального сервиса ИИ.',
      if (fallback) 'Резервный пример, не анализ вашего фото.',
    ];
    return Semantics(
      container: true,
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: simulation ? AppColors.neutralBg : AppColors.suggestedBg,
          border: Border.all(color: scheme.outline),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(simulation ? Icons.science : Icons.auto_awesome,
                color: simulation ? AppColors.neutral : AppColors.suggested),
            const SizedBox(width: 8),
            Expanded(
              child: DefaultTextStyle.merge(
                style: TextStyle(
                    color:
                        simulation ? AppColors.neutral : AppColors.suggested),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title,
                        style: const TextStyle(fontWeight: FontWeight.w700)),
                    for (final l in lines) Text(l),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _AnalysisPart extends ConsumerWidget {
  const _AnalysisPart({
    required this.material,
    required this.state,
    required this.simulation,
  });
  final MaterialItem material;
  final AnalysisState state;
  final bool simulation;

  void _close(BuildContext context) => context.canPop()
      ? context.pop()
      : context.go('/materials/${material.id}');

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ctrl = ref.read(analysisControllerProvider(material.id).notifier);
    final canRun = canEditMaterial(material) && material.images.isNotEmpty;

    switch (state.phase) {
      case AnalysisPhase.idle:
        if (!canEditMaterial(material)) {
          return const Text('Для этой партии анализ недоступен.');
        }
        if (material.images.isEmpty) {
          return const Text('Для анализа нужно фото.');
        }
        return AppButton(
          onPressed: ctrl.start,
          label: 'Проанализировать фото',
        );
      case AnalysisPhase.starting:
      case AnalysisPhase.polling:
        final queued = state.phase == AnalysisPhase.starting ||
            state.analysis == null ||
            state.analysis!.status == AnalysisStatus.pending;
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const LinearProgressIndicator(semanticsLabel: 'Анализ в процессе'),
            const SizedBox(height: 8),
            Semantics(
              liveRegion: true,
              child: Text(queued
                  ? 'Анализ поставлен в очередь…'
                  : 'Анализ выполняется…'),
            ),
            if (state.pollError != null) ...[
              const SizedBox(height: 8),
              const Text('Не удалось обновить статус. Пробуем ещё раз…'),
            ],
            const SizedBox(height: 8),
            Align(
              alignment: Alignment.centerLeft,
              child: AppButton(
                kind: AppButtonKind.text,
                onPressed: () => _close(context),
                label: 'Закрыть',
              ),
            ),
          ],
        );
      case AnalysisPhase.timedOut:
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text('Анализ занимает дольше обычного'),
            const SizedBox(height: 8),
            AppButton(
                kind: AppButtonKind.secondary,
                onPressed: ctrl.resume,
                label: 'Проверить снова'),
          ],
        );
      case AnalysisPhase.failed:
        return _Failed(
            material: material, state: state, canRun: canRun, ctrl: ctrl);
      case AnalysisPhase.done:
        final a = state.analysis!;
        if (!a.isCurrent) {
          return _Stale(canRun: canRun, onRetry: ctrl.start);
        }
        return _Result(analysis: a, simulation: simulation);
    }
  }
}

class _Stale extends StatelessWidget {
  const _Stale({required this.canRun, required this.onRetry});
  final bool canRun;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Row(children: [
          Icon(Icons.warning),
          SizedBox(width: 8),
          Expanded(
              child:
                  Text('Данные партии изменились. Запустите анализ заново.')),
        ]),
        const SizedBox(height: 8),
        if (canRun)
          AppButton(
              kind: AppButtonKind.secondary,
              onPressed: onRetry,
              label: 'Запустить заново'),
      ],
    );
  }
}

class _Failed extends StatelessWidget {
  const _Failed({
    required this.material,
    required this.state,
    required this.canRun,
    required this.ctrl,
  });
  final MaterialItem material;
  final AnalysisState state;
  final bool canRun;
  final AnalysisController ctrl;

  @override
  Widget build(BuildContext context) {
    final a = state.analysis;
    final startErr = state.startError;
    String text;
    var retryOk = true;
    if (startErr != null) {
      if (startErr.details?['reason'] == 'NO_IMAGES') {
        text = 'Добавьте хотя бы одно фото партии.';
        retryOk = false;
      } else if (startErr.statusCode == 429) {
        final n = state.retryAfterSeconds;
        text = n == null
            ? 'Слишком много запросов. Повторите позже.'
            : 'Слишком много запросов. Повторите через $n с.';
      } else {
        text = startErr.message;
      }
    } else {
      text =
          analysisErrorText(a?.errorCode, a?.status ?? AnalysisStatus.failed);
      retryOk = analysisRetryAllowed(a?.errorCode);
    }
    final interrupted = a?.status == AnalysisStatus.interrupted;
    final waiting = state.retryAfterSeconds != null;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Semantics(
          liveRegion: true,
          child: Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              border: Border.all(color: Theme.of(context).colorScheme.error),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(Icons.error, color: Theme.of(context).colorScheme.error),
                const SizedBox(width: 8),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('Анализ не удался.',
                          style: TextStyle(fontWeight: FontWeight.w700)),
                      Text(text),
                      if (startErr?.requestId != null)
                        Text('Код обращения: ${startErr!.requestId}'),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 8),
        if (state.failedAttempts >= 3) ...[
          const Text('Продолжите вручную: подтвердите характеристики ниже.'),
          const SizedBox(height: 8),
        ],
        if (retryOk && canRun)
          AppButton(
            onPressed: waiting ? null : ctrl.start,
            label: interrupted ? 'Запустить заново' : 'Повторить',
          ),
        const SizedBox(height: 4),
        const Text('Вы можете подтвердить характеристики вручную.'),
      ],
    );
  }
}

class _Result extends StatelessWidget {
  const _Result({required this.analysis, required this.simulation});
  final Analysis analysis;
  final bool simulation;

  @override
  Widget build(BuildContext context) {
    final r = analysis.result;
    if (r == null) {
      return const Text('Результат анализа недоступен.');
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text('Предложения ИИ', style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: 8),
        _FeatureCard(
            title: 'Цвет',
            feature: r.color,
            labels: colorLabels,
            simulation: simulation),
        _FeatureCard(
            title: 'Рисунок',
            feature: r.pattern,
            labels: patternLabels,
            simulation: simulation),
        _FeatureCard(
            title: 'Фактура',
            feature: r.texture,
            labels: textureLabels,
            simulation: simulation),
        const Card(
          child: ListTile(
            title: Text('Состав: Неизвестно — по фото не определяется.'),
          ),
        ),
        const SizedBox(height: 8),
        Text('Варианты применения',
            style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: 4),
        if (r.reuseOptions.isEmpty) const Text('Предложений по применению нет'),
        for (final o in r.reuseOptions)
          _ReuseCard(option: o, simulation: simulation),
        if (r.notes != null && r.notes!.isNotEmpty) ...[
          const SizedBox(height: 8),
          Text(r.notes!),
        ],
      ],
    );
  }
}

class _Badges extends StatelessWidget {
  const _Badges({required this.simulation});
  final bool simulation;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 6,
      children: [
        const Chip(
          avatar: Icon(Icons.auto_awesome, size: 16),
          label: Text('Предложение ИИ'),
          visualDensity: VisualDensity.compact,
        ),
        if (simulation)
          const Chip(
            avatar: Icon(Icons.science, size: 16),
            label: Text('Демо'),
            visualDensity: VisualDensity.compact,
          ),
      ],
    );
  }
}

class _FeatureCard extends StatelessWidget {
  const _FeatureCard({
    required this.title,
    required this.feature,
    required this.labels,
    required this.simulation,
  });
  final String title;
  final VisualFeature feature;
  final Map<String, String> labels;
  final bool simulation;

  @override
  Widget build(BuildContext context) {
    final f = feature;
    final lines = <String>[];
    if (f.isUnknown) {
      lines.add('Неизвестно');
    } else {
      if (f.value != null) lines.add(labels[f.value] ?? 'Другое');
      if (f.secondary.isNotEmpty) {
        lines.add(
            'Также: ${f.secondary.map((c) => labels[c] ?? 'другой').join(', ')}');
      }
      if ((f.description ?? '').isNotEmpty) lines.add(f.description!);
    }
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: Theme.of(context).textTheme.titleSmall),
            for (final l in lines) Text(l),
            Text('Уверенность: ${f.confidence.confidenceWord}'),
            const SizedBox(height: 4),
            _Badges(simulation: simulation),
          ],
        ),
      ),
    );
  }
}

class _ReuseCard extends StatelessWidget {
  const _ReuseCard({required this.option, required this.simulation});
  final ReuseOption option;
  final bool simulation;

  IconData get _icon => switch (option.suitability) {
        Level.high => Icons.thumb_up,
        Level.medium => Icons.thumbs_up_down,
        Level.low => Icons.thumb_down,
        Level.unknown => Icons.help_outline,
      };

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(option.label, style: Theme.of(context).textTheme.titleSmall),
            Row(children: [
              Icon(_icon, size: 18),
              const SizedBox(width: 6),
              Text('Применимость: ${option.suitability.suitabilityWord}'),
            ]),
            Text('Почему: ${option.reason}'),
            const SizedBox(height: 4),
            _Badges(simulation: simulation),
          ],
        ),
      ),
    );
  }
}

/// Block B: the person's own values and the explicit confirmation action.
/// AI values never enter here automatically.
class _HumanBlock extends ConsumerWidget {
  const _HumanBlock({required this.material});
  final MaterialItem material;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final m = material;
    final confirm = ref.watch(confirmMaterialProvider);
    final needsConfirm = canEditMaterial(m) && !m.isConfirmationCurrent;
    String provenance;
    if (m.confirmedAt == null) {
      provenance = 'Не подтверждено';
    } else if (!m.isConfirmationCurrent) {
      provenance = 'Требует повторного подтверждения';
    } else {
      final d = m.confirmedAt!.toLocal();
      String two(int v) => v.toString().padLeft(2, '0');
      provenance =
          'Подтверждено человеком, ${two(d.day)}.${two(d.month)}.${d.year}';
    }
    final rows = <(String, String)>[
      ('Тип', m.materialType?.label ?? 'Не указан'),
      ('Состояние', m.condition?.label ?? 'Не указано'),
      ('Масса', formatKg(m.balance?.totalKg ?? m.availableKg)),
      ('Город', m.city ?? 'Не указан'),
      ('Состав', m.composition ?? 'Неизвестно'),
    ];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text('Характеристики партии',
            style: Theme.of(context).textTheme.titleMedium),
        const Text('Указаны человеком, не ИИ.'),
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 4),
          child: Text(provenance,
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
        if (confirm.error != null) ...[
          const SizedBox(height: 8),
          LifecycleErrorView(
            error: confirm.error!,
            onRefresh: () {
              ref.invalidate(confirmMaterialProvider);
              ref.invalidate(materialDetailProvider(m.id));
            },
            onRetry: () =>
                ref.read(confirmMaterialProvider.notifier).confirm(m),
          ),
        ],
        if (needsConfirm) ...[
          const SizedBox(height: 8),
          const Text(
              'Вы подтверждаете характеристики партии. После подтверждения они используются в подборе и плане.'),
          const SizedBox(height: 8),
          AppButton(
            onPressed: confirm.busy
                ? null
                : () => ref.read(confirmMaterialProvider.notifier).confirm(m),
            loading: confirm.busy,
            loadingLabel: 'Отправка…',
            label: 'Подтвердить характеристики',
          ),
        ],
      ],
    );
  }
}
