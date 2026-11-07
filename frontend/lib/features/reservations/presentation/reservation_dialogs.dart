import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/format/mass_format.dart';
import '../../../core/theme/app_tokens.dart';
import '../../../core/ui/ui.dart';
import '../../../core/widgets/error_panel.dart';
import '../models/reservation_models.dart';
import '../providers/reservation_providers.dart';

const rejectReasonMax = 500;

void _toast(BuildContext context, String message) {
  ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(SnackBar(content: Text(message)));
}

/// Confirm (supplier). Dialog first; the server decides.
Future<void> confirmReservation(
    BuildContext context, WidgetRef ref, Reservation r) async {
  final who = r.buyerName ?? 'покупателя';
  final ok = await AppConfirmDialog.show(
    context,
    title: 'Подтвердить резерв?',
    message:
        'Будет удержано ${formatKg(r.quantityKg)} партии «${r.materialName}» для $who. Остальная масса останется свободной.',
    confirmLabel: 'Подтвердить резерв',
  );
  if (!ok || !context.mounted) return;
  final done = await ref.read(reservationActionProvider.notifier).run(
      r, ReservationAction.confirm,
      doneMessage: 'Резерв подтверждён. Удержано ${formatKg(r.quantityKg)}.');
  if (done && context.mounted) {
    _toast(context, ref.read(reservationActionProvider).doneMessage!);
  }
}

/// Buyer receipt confirmation. Uses the transferred quantity from the server.
Future<void> completeReservation(
    BuildContext context, WidgetRef ref, Reservation r) async {
  final kg = r.transaction?.transferredKg ?? r.quantityKg;
  final ok = await AppConfirmDialog.show(
    context,
    title: 'Подтвердить получение?',
    message:
        'Вы подтверждаете, что получили ${formatKg(kg)} партии «${r.materialName}». Действие нельзя отменить.',
    confirmLabel: 'Подтвердить получение',
  );
  if (!ok || !context.mounted) return;
  final done = await ref.read(reservationActionProvider.notifier).run(
      r, ReservationAction.complete,
      doneMessage: 'Получение подтверждено.');
  if (done && context.mounted) {
    _toast(context, 'Получение подтверждено.');
  }
}

/// Buyer cancel; the reason is optional.
Future<void> cancelReservation(
    BuildContext context, WidgetRef ref, Reservation r) async {
  ref.read(reservationActionProvider.notifier).clear();
  await AppBottomSheet.show<void>(
    context,
    title: 'Отменить заявку',
    builder: (_) => ReasonForm(
      reservation: r,
      required: false,
      intro:
          'Заявка на ${formatKg(r.quantityKg)} партии «${r.materialName}» будет отменена.'
          '${r.status == ReservationStatus.confirmed ? ' Удержанная масса вернётся продавцу.' : ''}',
      submitLabel: 'Отменить заявку',
      dismissLabel: 'Не отменять',
      action: ReservationAction.cancel,
      doneMessage: 'Заявка отменена.',
    ),
  );
}

/// Supplier rejection: the reason is mandatory.
Future<void> rejectReservation(
    BuildContext context, WidgetRef ref, Reservation r) async {
  ref.read(reservationActionProvider.notifier).clear();
  await AppBottomSheet.show<void>(
    context,
    title: 'Отклонить заявку',
    builder: (_) => ReasonForm(
      reservation: r,
      required: true,
      intro: 'Покупатель увидит причину.',
      submitLabel: 'Отклонить заявку',
      dismissLabel: 'Назад',
      action: ReservationAction.cancel,
      doneMessage: 'Заявка отклонена.',
    ),
  );
}

class ReasonForm extends ConsumerStatefulWidget {
  const ReasonForm({
    super.key,
    required this.reservation,
    required this.required,
    required this.intro,
    required this.submitLabel,
    required this.dismissLabel,
    required this.action,
    required this.doneMessage,
  });

  final Reservation reservation;
  final bool required;
  final String intro;
  final String submitLabel;
  final String dismissLabel;
  final ReservationAction action;
  final String doneMessage;

  @override
  ConsumerState<ReasonForm> createState() => _ReasonFormState();
}

class _ReasonFormState extends ConsumerState<ReasonForm> {
  final _reason = TextEditingController();

  @override
  void dispose() {
    _reason.dispose();
    super.dispose();
  }

  String? get _problem {
    final t = _reason.text.trim();
    if (widget.required && t.isEmpty) return 'Укажите причину отказа.';
    if (t.length > rejectReasonMax) {
      return 'Не более $rejectReasonMax символов.';
    }
    return null;
  }

  Future<void> _submit() async {
    if (_problem != null) {
      setState(() {});
      return;
    }
    final text = _reason.text.trim();
    final messenger = ScaffoldMessenger.of(context);
    final nav = Navigator.of(context);
    final ok = await ref.read(reservationActionProvider.notifier).run(
        widget.reservation, widget.action,
        reason: text.isEmpty ? null : text, doneMessage: widget.doneMessage);
    if (ok && mounted) {
      nav.pop();
      messenger
        ..hideCurrentSnackBar()
        ..showSnackBar(SnackBar(content: Text(widget.doneMessage)));
    }
  }

  @override
  Widget build(BuildContext context) {
    final s = ref.watch(reservationActionProvider);
    final problem = _problem;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(widget.intro, style: AppTypography.body),
        const SizedBox(height: AppSpacing.md),
        AppTextField(
          label: widget.required ? 'Причина отказа' : 'Причина (необязательно)',
          controller: _reason,
          maxLines: 3,
          enabled: !s.busy,
          helper: '${_reason.text.characters.length} из $rejectReasonMax',
          errorText: _reason.text.isEmpty ? null : problem,
          onChanged: (_) => setState(() {}),
        ),
        if (widget.required && _reason.text.trim().isEmpty)
          const Padding(
            padding: EdgeInsets.only(top: AppSpacing.xs),
            child: Text('Укажите причину отказа.'),
          ),
        if (s.error != null) ...[
          const SizedBox(height: AppSpacing.md),
          ErrorBanner(error: s.error!),
        ],
        const SizedBox(height: AppSpacing.lg),
        AppButton(
          label: widget.submitLabel,
          kind: AppButtonKind.destructive,
          loading: s.busy,
          loadingLabel: 'Отправка…',
          onPressed: problem == null ? _submit : null,
        ),
        const SizedBox(height: AppSpacing.sm),
        AppButton(
          label: widget.dismissLabel,
          kind: AppButtonKind.text,
          onPressed: s.busy ? null : () => Navigator.of(context).pop(),
        ),
      ],
    );
  }
}

/// Supplier transfer: optional actual quantity, empty means the full held amount.
Future<void> transferReservation(
    BuildContext context, WidgetRef ref, Reservation r) async {
  ref.read(reservationActionProvider.notifier).clear();
  await AppBottomSheet.show<void>(
    context,
    title: 'Отметить передачу',
    builder: (_) => _TransferForm(reservation: r),
  );
}

class _TransferForm extends ConsumerStatefulWidget {
  const _TransferForm({required this.reservation});
  final Reservation reservation;

  @override
  ConsumerState<_TransferForm> createState() => _TransferFormState();
}

class _TransferFormState extends ConsumerState<_TransferForm> {
  final _kg = TextEditingController();

  @override
  void dispose() {
    _kg.dispose();
    super.dispose();
  }

  String? get _problem {
    final t = normalizeKg(_kg.text);
    if (t.isEmpty) return null;
    if (!RegExp(r'^\d+(\.\d+)?$').hasMatch(t)) {
      return 'Введите число, например 12,5.';
    }
    if (!RegExp(r'^\d+(\.\d{1,3})?$').hasMatch(t)) {
      return 'Не более 3 знаков после запятой.';
    }
    final v = double.parse(t);
    if (v <= 0) return 'Введите количество больше нуля.';
    final max = double.tryParse(widget.reservation.quantityKg);
    if (max != null && v > max) {
      return 'Нельзя передать больше удержанного: ${formatKg(widget.reservation.quantityKg)}.';
    }
    return null;
  }

  Future<void> _submit() async {
    if (_problem != null) return;
    final nav = Navigator.of(context);
    final messenger = ScaffoldMessenger.of(context);
    final t = normalizeKg(_kg.text);
    const done = 'Передача отмечена. Ждём подтверждения получения покупателем.';
    // Empty field: send no value, the server transfers the whole held amount.
    final ok = await ref.read(reservationActionProvider.notifier).run(
        widget.reservation, ReservationAction.transfer,
        transferredKg: t.isEmpty ? null : t, doneMessage: done);
    if (ok && mounted) {
      nav.pop();
      messenger
        ..hideCurrentSnackBar()
        ..showSnackBar(const SnackBar(content: Text(done)));
    }
  }

  @override
  Widget build(BuildContext context) {
    final s = ref.watch(reservationActionProvider);
    final problem = _problem;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text('Удержано: ${formatKg(widget.reservation.quantityKg)}',
            style: AppTypography.body),
        const SizedBox(height: AppSpacing.md),
        AppTextField(
          label: 'Фактически передано, кг',
          controller: _kg,
          suffixText: 'кг',
          enabled: !s.busy,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          helper:
              'Оставьте пустым, если передано всё удержанное количество. Недопереданная часть вернётся в свободный остаток.',
          errorText: problem,
          onChanged: (_) => setState(() {}),
        ),
        if (s.error != null) ...[
          const SizedBox(height: AppSpacing.md),
          ErrorBanner(error: s.error!),
        ],
        const SizedBox(height: AppSpacing.lg),
        AppButton(
          label: 'Подтвердить передачу',
          loading: s.busy,
          loadingLabel: 'Отправка…',
          onPressed: problem == null ? _submit : null,
        ),
      ],
    );
  }
}
