import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/network/api_exception.dart';
import '../../../core/widgets/error_panel.dart';
import '../models/material_models.dart';
import '../providers/material_providers.dart';
import 'material_form_fields.dart';
import 'material_form_model.dart';

class MaterialEditScreen extends ConsumerWidget {
  const MaterialEditScreen({super.key, required this.materialId});
  final String materialId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(materialDetailProvider(materialId));
    return Scaffold(
      appBar: AppBar(title: const Text('Изменить партию')),
      body: async.when(
        loading: () => const Center(
          child: CircularProgressIndicator(semanticsLabel: 'Загрузка…'),
        ),
        error: (e, _) => Padding(
          padding: const EdgeInsets.all(16),
          child: ErrorBanner(
            error: e is ApiException ? e : ApiException.network(),
            onRetry: () => ref.invalidate(materialDetailProvider(materialId)),
          ),
        ),
        data: (m) => m.isOwnerView
            ? EditForm(item: m)
            : const Center(child: Text('Нет доступа к изменению этой партии.')),
      ),
    );
  }
}

class EditForm extends ConsumerStatefulWidget {
  const EditForm({super.key, required this.item});
  final MaterialItem item;

  @override
  ConsumerState<EditForm> createState() => _EditFormState();
}

class _EditFormState extends ConsumerState<EditForm> {
  final _formKey = GlobalKey<FormState>();
  late final MaterialFormModel _model = MaterialFormModel(widget.item);

  @override
  void dispose() {
    _model.dispose();
    super.dispose();
  }

  void _save() {
    final provider = editMaterialProvider(widget.item);
    if (ref.read(provider).saving) return;
    if (!(_formKey.currentState?.validate() ?? false)) return;
    final fields = _model.diff(ref.read(provider).base);
    if (fields.isEmpty) {
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('Нет изменений.')));
      return;
    }
    ref.read(provider.notifier).save(fields);
  }

  @override
  Widget build(BuildContext context) {
    final provider = editMaterialProvider(widget.item);
    ref.listen(provider, (prev, next) {
      if (next.saved != null && prev?.saved == null) {
        ScaffoldMessenger.of(context)
            .showSnackBar(const SnackBar(content: Text('Сохранено.')));
        context.pop(true);
      }
    });
    final s = ref.watch(provider);
    final busy = s.saving || s.refreshing;
    final fe = s.error?.fieldErrors ?? const <String, String>{};
    final blocked = (s.error?.details?['blocked_fields'] as List?)
            ?.whereType<String>()
            .toList() ??
        const <String>[];
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 600),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (s.isVersionConflict) ...[
                ErrorBanner(
                  error: ApiException(
                    code: 'VERSION_CONFLICT',
                    message: 'Данные изменились, пока вы их редактировали'
                        '${s.currentServerVersion == null ? '' : ' (версия на сервере: ${s.currentServerVersion})'}. '
                        'Обновите данные и повторите изменения. Ваши значения в форме сохранены.',
                    statusCode: 409,
                  ),
                ),
                const SizedBox(height: 8),
                OutlinedButton(
                  onPressed:
                      busy ? null : () => ref.read(provider.notifier).refresh(),
                  child: Text(s.refreshing ? 'Обновление…' : 'Обновить данные'),
                ),
                const SizedBox(height: 12),
              ] else if (s.isActiveObligations) ...[
                ErrorBanner(
                  error: ApiException(
                    code: 'ACTIVE_OBLIGATIONS',
                    message: 'Нельзя изменить: есть активные заявки.'
                        '${blocked.isEmpty ? '' : ' Поля: ${blocked.join(', ')}.'}',
                    statusCode: 409,
                  ),
                ),
                const SizedBox(height: 12),
              ] else if (s.error != null) ...[
                ErrorBanner(error: s.error!),
                const SizedBox(height: 12),
              ],
              Form(
                key: _formKey,
                child: MaterialFormFields(
                  model: _model,
                  enabled: !busy,
                  fieldErrors: fe,
                  requireAll: false,
                ),
              ),
              const SizedBox(height: 20),
              FilledButton(
                onPressed: busy ? null : _save,
                child: Text(s.saving ? 'Сохранение…' : 'Сохранить'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
