import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/config/app_config.dart';
import '../../../core/widgets/error_panel.dart';
import '../providers/material_providers.dart';
import 'material_form_fields.dart';
import 'material_form_model.dart';

class MaterialCreateScreen extends ConsumerStatefulWidget {
  const MaterialCreateScreen({super.key});

  @override
  ConsumerState<MaterialCreateScreen> createState() =>
      _MaterialCreateScreenState();
}

class _MaterialCreateScreenState extends ConsumerState<MaterialCreateScreen> {
  final _formKey = GlobalKey<FormState>();
  final _model = MaterialFormModel();

  @override
  void dispose() {
    _model.dispose();
    super.dispose();
  }

  void _submit() {
    if (ref.read(createMaterialProvider).saving) return;
    if (ref.read(createMaterialProvider).created == null &&
        !(_formKey.currentState?.validate() ?? false)) {
      return;
    }
    ref.read(createMaterialProvider.notifier).submit(_model.toCreate());
  }

  Future<void> _pick() async {
    try {
      final picked = await ref.read(photoPickerProvider).pick();
      ref.read(createMaterialProvider.notifier).addPhotos(picked);
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Не удалось выбрать фото.')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    ref.listen(createMaterialProvider, (prev, next) {
      if (next.completed && !(prev?.completed ?? false)) {
        ScaffoldMessenger.of(context)
            .showSnackBar(const SnackBar(content: Text('Черновик сохранён.')));
        context.pushReplacement('/materials/${next.created!.id}');
      }
    });
    final s = ref.watch(createMaterialProvider);
    final locked = s.saving || s.created != null;
    final fe = s.error?.fieldErrors ?? const <String, String>{};

    final form = Form(
      key: _formKey,
      child: MaterialFormFields(
        model: _model,
        enabled: !locked,
        fieldErrors: fe,
      ),
    );
    final photos = _PhotosSection(onPick: _pick);

    return Scaffold(
      appBar: AppBar(title: const Text('Новая партия')),
      body: LayoutBuilder(builder: (context, c) {
        final wide = c.maxWidth >= 840;
        return SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Center(
            child: ConstrainedBox(
              constraints: BoxConstraints(maxWidth: wide ? 1100 : 600),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  if (s.error != null) ...[
                    ErrorBanner(error: s.error!),
                    if (fe.isNotEmpty)
                      const Padding(
                        padding: EdgeInsets.only(top: 4),
                        child: Text('Проверьте поля формы.'),
                      ),
                    const SizedBox(height: 12),
                  ],
                  if (s.created != null && !s.allPhotosDone && !s.saving) ...[
                    const _PartialBanner(),
                    const SizedBox(height: 12),
                  ],
                  wide
                      ? Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(child: form),
                            const SizedBox(width: 24),
                            Expanded(child: photos),
                          ],
                        )
                      : Column(
                          // Stretch keeps the photo block on the same left
                          // edge as the form fields (DEV-03).
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [form, const SizedBox(height: 16), photos]),
                  const SizedBox(height: 20),
                  FilledButton(
                    onPressed: s.saving ? null : _submit,
                    child: Text(s.saving
                        ? 'Сохранение…'
                        : s.created != null
                            ? 'Повторить загрузку фото'
                            : 'Сохранить черновик'),
                  ),
                  if (s.created != null && !s.saving && !s.allPhotosDone) ...[
                    const SizedBox(height: 8),
                    OutlinedButton(
                      onPressed: () => context
                          .pushReplacement('/materials/${s.created!.id}'),
                      child: const Text('Открыть партию без этих фото'),
                    ),
                  ],
                ],
              ),
            ),
          ),
        );
      }),
    );
  }
}

class _PartialBanner extends StatelessWidget {
  const _PartialBanner();

  @override
  Widget build(BuildContext context) {
    return Semantics(
      liveRegion: true,
      child: const Text(
        'Партия сохранена, но не все фото загружены. Введённые данные сохранены.',
      ),
    );
  }
}

class _PhotosSection extends ConsumerWidget {
  const _PhotosSection({required this.onPick});
  final VoidCallback onPick;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = ref.watch(createMaterialProvider);
    final ctrl = ref.read(createMaterialProvider.notifier);
    final locked = s.saving || s.created != null;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Фото партии (до 5)',
            style: Theme.of(context).textTheme.titleMedium),
        const Text('JPEG, PNG или WebP, до 10 МБ каждое.'),
        const SizedBox(height: 8),
        if (s.photoNotice != null)
          Semantics(
            liveRegion: true,
            child: Text(s.photoNotice!,
                style: TextStyle(color: Theme.of(context).colorScheme.error)),
          ),
        for (var i = 0; i < s.photos.length; i++)
          _PhotoTile(
            index: i,
            upload: s.photos[i],
            onRemove: locked ? null : () => ctrl.removePhoto(i),
          ),
        if (ref.watch(appConfigProvider).useDemoData)
          const Padding(
            padding: EdgeInsets.only(bottom: 8),
            child: Text('Демо: фото сохраняется только на этом устройстве.'),
          ),
        const SizedBox(height: 8),
        Align(
            alignment: Alignment.centerLeft,
            child: OutlinedButton.icon(
              onPressed: locked || s.photos.length >= 5 ? null : onPick,
              icon: const Icon(Icons.add_a_photo),
              label: const Text('Добавить фото'),
            )),
      ],
    );
  }
}

class _PhotoTile extends StatelessWidget {
  const _PhotoTile({
    required this.index,
    required this.upload,
    required this.onRemove,
  });
  final int index;
  final PhotoUpload upload;
  final VoidCallback? onRemove;

  @override
  Widget build(BuildContext context) {
    final status = switch (upload.status) {
      PhotoUploadStatus.pending => 'Ожидает отправки',
      PhotoUploadStatus.uploading => 'Загрузка…',
      PhotoUploadStatus.done => 'Загружено',
      PhotoUploadStatus.failed =>
        'Ошибка: ${upload.error?.message ?? 'не удалось загрузить'}',
    };
    return Card(
      child: ListTile(
        leading: ClipRRect(
          borderRadius: BorderRadius.circular(4),
          child: Image.memory(
            upload.photo.bytes,
            width: 56,
            height: 56,
            fit: BoxFit.cover,
            errorBuilder: (_, __, ___) =>
                const SizedBox(width: 56, height: 56, child: Icon(Icons.image)),
          ),
        ),
        title: Text(upload.photo.name,
            maxLines: 1, overflow: TextOverflow.ellipsis),
        subtitle: Text(status),
        trailing: onRemove == null
            ? null
            : IconButton(
                tooltip: 'Убрать фото ${index + 1} из списка',
                icon: const Icon(Icons.close),
                onPressed: onRemove,
              ),
      ),
    );
  }
}
