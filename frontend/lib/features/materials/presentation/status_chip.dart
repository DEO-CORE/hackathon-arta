import 'package:flutter/material.dart';

import '../../../core/ui/app_status_badge.dart';
import '../models/material_enums.dart';

class _Style {
  const _Style(this.tone, this.icon, this.helper, {this.outlined = false});
  final AppTone tone;
  final IconData icon;
  final String helper;
  final bool outlined;
}

_Style _styleOf(MaterialStatus s) => switch (s) {
      MaterialStatus.draft =>
        const _Style(AppTone.neutral, Icons.edit_note, 'Не виден покупателям.'),
      MaterialStatus.available =>
        const _Style(AppTone.success, Icons.storefront, 'Вся масса свободна.'),
      MaterialStatus.partiallyAllocated => const _Style(
          AppTone.accent,
          Icons.pie_chart,
          'Часть массы удержана или передана, свободная масса ещё есть.'),
      MaterialStatus.reserved => const _Style(AppTone.accent, Icons.lock,
          'Свободной массы нет, есть активный резерв.',
          outlined: true),
      MaterialStatus.completed => const _Style(
          AppTone.neutral, Icons.done_all, 'Вся масса выбыла.',
          outlined: true),
      MaterialStatus.archived =>
        const _Style(AppTone.neutral, Icons.archive, 'Скрыто владельцем.'),
      MaterialStatus.unknown => const _Style(AppTone.neutral,
          Icons.help_outline, 'Статус не распознан приложением.'),
    };

String statusHelper(MaterialStatus s) => _styleOf(s).helper;

/// Status is always text + icon, never colour only.
class MaterialStatusChip extends StatelessWidget {
  const MaterialStatusChip({super.key, required this.status});
  final MaterialStatus status;

  @override
  Widget build(BuildContext context) {
    final st = _styleOf(status);
    return AppStatusBadge(
      label: status.label,
      icon: st.icon,
      tone: st.tone,
      outlined: st.outlined,
      semanticsLabel: 'Статус: ${status.label}',
    );
  }
}
