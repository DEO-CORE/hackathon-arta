import 'dart:typed_data';

import 'package:flutter/material.dart';

import '../theme/app_tokens.dart';

enum AppPhotoStatus { pending, uploading, failed, done }

class AppPhotoTileData {
  const AppPhotoTileData({
    required this.name,
    this.bytes,
    this.status = AppPhotoStatus.pending,
    this.errorText,
  });

  final String name;
  final Uint8List? bytes;
  final AppPhotoStatus status;
  final String? errorText;
}

/// 3-column photo grid: add tile first, then photos with per-tile state,
/// counter "N из max" and the limits text. Removal and retry controls are
/// 48 dp with accessible names. Static (no animation).
class AppPhotoUpload extends StatelessWidget {
  const AppPhotoUpload({
    super.key,
    required this.photos,
    required this.onAdd,
    this.onRemove,
    this.onRetry,
    this.maxPhotos = 5,
    this.limitsText = 'JPEG, PNG или WebP, до 10 МБ каждое.',
    this.note,
  });

  final List<AppPhotoTileData> photos;

  /// Null disables adding (saving in progress, or the limit is reached).
  final VoidCallback? onAdd;
  final ValueChanged<int>? onRemove;
  final ValueChanged<int>? onRetry;
  final int maxPhotos;
  final String limitsText;
  final String? note;

  @override
  Widget build(BuildContext context) {
    final canAdd = onAdd != null && photos.length < maxPhotos;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Expanded(child: Text('Фото партии', style: AppTypography.title)),
            Text('${photos.length} из $maxPhotos',
                style: AppTypography.bodySmall
                    .copyWith(color: AppColors.textSecondary)),
          ],
        ),
        const SizedBox(height: AppSpacing.md),
        LayoutBuilder(builder: (context, c) {
          const gap = AppSpacing.sm;
          final w = (c.maxWidth - gap * 2) / 3;
          return Wrap(
            spacing: gap,
            runSpacing: gap,
            children: [
              SizedBox(
                width: w,
                height: w,
                child: _AddTile(onAdd: canAdd ? onAdd : null),
              ),
              for (var i = 0; i < photos.length; i++)
                SizedBox(
                  width: w,
                  height: w,
                  child: _PhotoTile(
                    index: i,
                    data: photos[i],
                    onRemove: onRemove == null ? null : () => onRemove!(i),
                    onRetry: onRetry == null ? null : () => onRetry!(i),
                  ),
                ),
            ],
          );
        }),
        const SizedBox(height: AppSpacing.sm),
        Text(limitsText, style: AppTypography.caption),
        if (note != null)
          Padding(
            padding: const EdgeInsets.only(top: AppSpacing.xs),
            child: Text(note!, style: AppTypography.caption),
          ),
      ],
    );
  }
}

class _AddTile extends StatelessWidget {
  const _AddTile({required this.onAdd});
  final VoidCallback? onAdd;

  @override
  Widget build(BuildContext context) {
    final color = onAdd == null ? AppColors.textSecondary : AppColors.linkText;
    return Semantics(
      button: true,
      enabled: onAdd != null,
      label: 'Добавить фото',
      excludeSemantics: true,
      child: Material(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppRadius.iconTile),
        child: InkWell(
          borderRadius: BorderRadius.circular(AppRadius.iconTile),
          onTap: onAdd,
          child: CustomPaint(
            painter: _DashedBorder(color: AppColors.controlBorder),
            child: Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.add_a_photo, color: color),
                  const SizedBox(height: AppSpacing.xs),
                  Text('Добавить фото',
                      textAlign: TextAlign.center,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: AppTypography.caption.copyWith(color: color)),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _DashedBorder extends CustomPainter {
  const _DashedBorder({required this.color});
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final rrect = RRect.fromRectAndRadius(
        Offset.zero & size, const Radius.circular(AppRadius.iconTile));
    final path = Path()..addRRect(rrect);
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5;
    for (final m in path.computeMetrics()) {
      for (double d = 0; d < m.length; d += 10) {
        canvas.drawPath(m.extractPath(d, d + 5), paint);
      }
    }
  }

  @override
  bool shouldRepaint(_DashedBorder old) => old.color != color;
}

class _PhotoTile extends StatelessWidget {
  const _PhotoTile({
    required this.index,
    required this.data,
    required this.onRemove,
    required this.onRetry,
  });

  final int index;
  final AppPhotoTileData data;
  final VoidCallback? onRemove;
  final VoidCallback? onRetry;

  String get _status => switch (data.status) {
        AppPhotoStatus.pending => 'Ожидает отправки',
        AppPhotoStatus.uploading => 'Загрузка…',
        AppPhotoStatus.done => 'Загружено',
        AppPhotoStatus.failed => 'Ошибка загрузки',
      };

  @override
  Widget build(BuildContext context) {
    final failed = data.status == AppPhotoStatus.failed;
    return Semantics(
      container: true,
      label: 'Фото ${index + 1}, ${data.name}: $_status',
      child: ClipRRect(
        borderRadius: BorderRadius.circular(AppRadius.iconTile),
        child: Stack(
          fit: StackFit.expand,
          children: [
            ColoredBox(
              color: AppColors.surfaceSunken,
              child: data.bytes == null
                  ? const Icon(Icons.image, color: AppColors.textSecondary)
                  : Image.memory(data.bytes!,
                      fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) => const Icon(Icons.image,
                          color: AppColors.textSecondary)),
            ),
            Positioned(
              left: 0,
              right: 0,
              bottom: 0,
              child: ColoredBox(
                color: AppColors.overlaySurface,
                child: Padding(
                  padding: const EdgeInsets.all(AppSpacing.xs),
                  child: Row(
                    children: [
                      if (data.status == AppPhotoStatus.uploading)
                        const SizedBox(
                          width: 12,
                          height: 12,
                          child: CircularProgressIndicator(
                              strokeWidth: 2, semanticsLabel: 'Загрузка'),
                        )
                      else
                        Icon(
                            failed
                                ? Icons.error
                                : data.status == AppPhotoStatus.done
                                    ? Icons.check_circle
                                    : Icons.schedule,
                            size: 14,
                            color: failed
                                ? AppColors.error
                                : AppColors.textSecondary),
                      const SizedBox(width: AppSpacing.xs),
                      Expanded(
                        child: Text(_status,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: AppTypography.caption
                                .copyWith(color: AppColors.text)),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            if (onRemove != null)
              Positioned(
                top: 0,
                right: 0,
                child: IconButton(
                  tooltip: 'Убрать фото ${index + 1} из списка',
                  style: IconButton.styleFrom(
                      backgroundColor: AppColors.overlaySurface,
                      minimumSize: const Size(48, 48)),
                  icon: const Icon(Icons.close),
                  onPressed: onRemove,
                ),
              ),
            if (failed && onRetry != null)
              Positioned(
                top: 0,
                left: 0,
                child: IconButton(
                  tooltip: 'Повторить загрузку фото ${index + 1}',
                  style: IconButton.styleFrom(
                      backgroundColor: AppColors.overlaySurface,
                      minimumSize: const Size(48, 48)),
                  icon: const Icon(Icons.refresh),
                  onPressed: onRetry,
                ),
              ),
          ],
        ),
      ),
    );
  }
}
