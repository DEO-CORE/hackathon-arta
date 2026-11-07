import 'package:flutter/material.dart';

import '../models/material_enums.dart';

class _Style {
  const _Style(this.fg, this.bg, this.icon, this.helper, {this.border});
  final Color fg;
  final Color bg;
  final IconData icon;
  final String helper;
  final Color? border;
}

const _neutralFg = Color(0xFF5B5048);
const _neutralBg = Color(0xFFEFE6DE);

_Style _styleOf(MaterialStatus s) => switch (s) {
      MaterialStatus.draft => const _Style(
          _neutralFg, _neutralBg, Icons.edit_note, 'Не виден покупателям.'),
      MaterialStatus.available => const _Style(Color(0xFF1B6B3A),
          Color(0xFFDDF3E4), Icons.storefront, 'Вся масса свободна.'),
      MaterialStatus.partiallyAllocated => const _Style(
          Color(0xFF3A1800),
          Color(0xFFFFDCC2),
          Icons.pie_chart,
          'Часть массы удержана или передана, свободная масса ещё есть.'),
      MaterialStatus.reserved => const _Style(
          Color(0xFF3A1800),
          Color(0xFFFFDCC2),
          Icons.lock,
          'Свободной массы нет, есть активный резерв.',
          border: Color(0xFF9A3F00)),
      MaterialStatus.completed => const _Style(
          _neutralFg, _neutralBg, Icons.done_all, 'Вся масса выбыла.',
          border: Color(0xFF857A71)),
      MaterialStatus.archived => const _Style(
          _neutralFg, _neutralBg, Icons.archive, 'Скрыто владельцем.'),
      MaterialStatus.unknown => const _Style(_neutralFg, _neutralBg,
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
    return Semantics(
      label: 'Статус: ${status.label}',
      excludeSemantics: true,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: st.bg,
          borderRadius: BorderRadius.circular(16),
          border: st.border == null ? null : Border.all(color: st.border!),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(st.icon, size: 16, color: st.fg),
            const SizedBox(width: 6),
            Flexible(
              child: Text(
                status.label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(color: st.fg, fontSize: 13),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
