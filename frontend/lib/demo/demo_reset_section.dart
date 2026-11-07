import 'package:arta/core/ui/app_button.dart';
import 'package:arta/core/ui/ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../core/config/app_config.dart';
import '../features/materials/providers/material_providers.dart';
import 'demo_material_repository.dart';

/// "Демо-режим" block of the profile screen. Renders nothing outside demo.
class DemoResetSection extends ConsumerWidget {
  const DemoResetSection({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (!ref.watch(appConfigProvider).useDemoData) {
      return const SizedBox.shrink();
    }
    return Padding(
      padding: const EdgeInsets.only(top: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text('Демо-режим', style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 8),
          OutlinedButton(
            onPressed: () => _openDialog(context, ref),
            child: const Text('Сбросить демо-данные'),
          ),
        ],
      ),
    );
  }

  Future<void> _openDialog(BuildContext context, WidgetRef ref) async {
    final done = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (_) => const _ResetDialog(),
    );
    if (done == true && context.mounted) {
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('Демо-данные сброшены.')));
      context.go('/materials');
    }
  }
}

class _ResetDialog extends ConsumerStatefulWidget {
  const _ResetDialog();

  @override
  ConsumerState<_ResetDialog> createState() => _ResetDialogState();
}

class _ResetDialogState extends ConsumerState<_ResetDialog> {
  bool _busy = false;
  bool _failed = false;

  Future<void> _reset() async {
    if (_busy) return;
    setState(() {
      _busy = true;
      _failed = false;
    });
    try {
      final repo = ref.read(materialRepositoryProvider);
      if (repo is! DemoResettable) throw StateError('not a demo repository');
      await (repo as DemoResettable).resetDemoData();
      ref.invalidate(catalogProvider);
      ref.invalidate(materialDetailProvider);
      if (mounted) Navigator.of(context).pop(true);
    } catch (_) {
      if (mounted) {
        setState(() {
          _busy = false;
          _failed = true;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Сбросить демо-данные?'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
              'Все изменения в демо будут удалены: созданные партии, фото, подтверждения и результаты анализа. Данные вернутся к исходному набору. Реальные данные это не затрагивает.'),
          if (_failed) ...[
            const SizedBox(height: 12),
            Semantics(
              liveRegion: true,
              child: Text('Не удалось сбросить демо-данные. Повторите позже.',
                  style: TextStyle(color: Theme.of(context).colorScheme.error)),
            ),
          ],
        ],
      ),
      actions: [
        AppButton(
          label: 'Отмена',
          kind: AppButtonKind.text,
          autofocus: true,
          onPressed: _busy ? null : () => Navigator.of(context).pop(false),
        ),
        AppButton(
          kind: AppButtonKind.destructive,
          onPressed: _busy ? null : _reset,
          label: _busy
              ? 'Сброс…'
              : _failed
                  ? 'Повторить'
                  : 'Сбросить',
        ),
      ],
    );
  }
}
