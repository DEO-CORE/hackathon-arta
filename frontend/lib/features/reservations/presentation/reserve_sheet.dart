import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/format/mass_format.dart';
import '../../../core/theme/app_tokens.dart';
import '../../../core/ui/ui.dart';
import '../../../core/widgets/error_panel.dart';
import '../../materials/models/material_models.dart';
import '../models/reservation_models.dart';
import '../providers/reservation_providers.dart';

/// Opens the two-step reservation request. Returns true when the server
/// created the request.
Future<bool> showReserveSheet(BuildContext context, MaterialItem item) async {
  final done = await AppBottomSheet.show<bool>(
    context,
    title: 'Запросить резерв',
    builder: (_) => ReserveForm(item: item),
  );
  return done == true;
}

class ReserveForm extends ConsumerStatefulWidget {
  const ReserveForm({super.key, required this.item});
  final MaterialItem item;

  @override
  ConsumerState<ReserveForm> createState() => _ReserveFormState();
}

class _ReserveFormState extends ConsumerState<ReserveForm> {
  final _formKey = GlobalKey<FormState>();
  final _kg = TextEditingController();
  bool _confirmStep = false;

  @override
  void dispose() {
    _kg.dispose();
    super.dispose();
  }

  String? _validate(String? v) => validateRequestKg(v, widget.item.availableKg);

  void _next() {
    if (_formKey.currentState!.validate()) {
      ref.read(reserveProvider(widget.item.id).notifier).clearError();
      setState(() => _confirmStep = true);
    }
  }

  Future<void> _send() async {
    final nav = Navigator.of(context);
    final messenger = ScaffoldMessenger.of(context);
    final ok = await ref
        .read(reserveProvider(widget.item.id).notifier)
        .submit(quantityKg: _kg.text);
    if (ok && mounted) {
      nav.pop(true);
      messenger
        ..hideCurrentSnackBar()
        ..showSnackBar(const SnackBar(
            content: Text(
                'Заявка отправлена. Продавец ответит в разделе «Заявки».')));
    }
  }

  @override
  Widget build(BuildContext context) {
    final item = widget.item;
    final s = ref.watch(reserveProvider(item.id));
    final price = item.pricePerKg == null
        ? 'Цена не указана; условия согласуйте с продавцом'
        : 'Цена: ${formatDecimal(item.pricePerKg!)} KGS/кг';
    return PopScope(
      canPop: !s.busy,
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(item.name, style: AppTypography.title),
            Text('Свободно сейчас: ${formatKg(item.availableKg)}',
                style: AppTypography.bodySmall
                    .copyWith(color: AppColors.textSecondary)),
            const SizedBox(height: AppSpacing.md),
            if (!_confirmStep) ...[
              AppTextField(
                label: 'Количество, кг',
                controller: _kg,
                suffixText: 'кг',
                keyboardType:
                    const TextInputType.numberWithOptions(decimal: true),
                helper: 'Не больше свободного количества',
                validator: _validate,
                textInputAction: TextInputAction.done,
                onFieldSubmitted: (_) => _next(),
              ),
              const SizedBox(height: AppSpacing.sm),
              Text(price),
              const SizedBox(height: AppSpacing.md),
              const _InfoNote(),
              const SizedBox(height: AppSpacing.lg),
              AppButton(label: 'Продолжить', onPressed: _next),
            ] else ...[
              Text('Количество: ${formatKg(normalizeKg(_kg.text))}'),
              const SizedBox(height: AppSpacing.xs),
              Text(price),
              const SizedBox(height: AppSpacing.sm),
              const Text('Продавец увидит вашу организацию и количество.'),
              if (s.error != null) ...[
                const SizedBox(height: AppSpacing.md),
                ErrorBanner(error: s.error!),
              ],
              const SizedBox(height: AppSpacing.lg),
              AppButton(
                label: s.error != null && s.error!.statusCode == null
                    ? 'Повторить отправку'
                    : 'Отправить заявку',
                loading: s.busy,
                loadingLabel: 'Отправка…',
                onPressed: _send,
              ),
              const SizedBox(height: AppSpacing.sm),
              AppButton(
                label: 'Назад',
                kind: AppButtonKind.secondary,
                onPressed: s.busy
                    ? null
                    : () {
                        ref
                            .read(reserveProvider(item.id).notifier)
                            .clearError();
                        setState(() => _confirmStep = false);
                      },
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _InfoNote extends StatelessWidget {
  const _InfoNote();

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.all(AppSpacing.md),
        decoration: BoxDecoration(
          color: AppColors.surfaceSunken,
          borderRadius: BorderRadius.circular(AppRadius.md),
        ),
        child: const Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(Icons.info_outline, size: 20),
            SizedBox(width: AppSpacing.sm),
            Expanded(
              child: Text(
                  'Заявка не списывает деньги и не гарантирует запас, пока продавец не подтвердит резерв.'),
            ),
          ],
        ),
      );
}
