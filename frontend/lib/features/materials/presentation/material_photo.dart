import 'dart:io' show File;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_tokens.dart';
import '../../../core/ui/app_skeleton.dart';
import '../providers/material_providers.dart';

/// Shows a photo only through the short-lived signed URL the API returns.
class MaterialPhoto extends ConsumerWidget {
  const MaterialPhoto({
    super.key,
    required this.materialId,
    required this.imageId,
    required this.label,
    this.size = 96,
  });

  final String materialId;
  final String? imageId;
  final String label;
  final double size;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    Widget placeholder(String text) => Container(
          width: size,
          height: size,
          color: Theme.of(context).colorScheme.secondaryContainer,
          alignment: Alignment.center,
          padding: const EdgeInsets.all(4),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.image_not_supported,
                  color: AppColors.textSecondary),
              if (size >= 80) Text(text, style: const TextStyle(fontSize: 12)),
            ],
          ),
        );
    final id = imageId;
    if (id == null) return placeholder('Нет фото');
    final url = ref
        .watch(materialImageUrlProvider((materialId: materialId, imageId: id)));
    return ClipRRect(
      borderRadius: BorderRadius.circular(8),
      child: url.when(
        loading: () => Semantics(
          label: 'Загрузка фото',
          child: AppSkeleton(width: size, height: size),
        ),
        error: (_, __) => placeholder('Фото недоступно'),
        data: (u) => Semantics(
          label: label,
          image: true,
          child: u.url.startsWith('file:')
              // Demo only: a photo copied into the app's private demo folder.
              ? Image.file(
                  File.fromUri(Uri.parse(u.url)),
                  width: size,
                  height: size,
                  fit: BoxFit.cover,
                  errorBuilder: (_, __, ___) => placeholder('Фото недоступно'),
                )
              : Image.network(
                  u.url,
                  width: size,
                  height: size,
                  fit: BoxFit.cover,
                  errorBuilder: (_, __, ___) => placeholder('Фото недоступно'),
                ),
        ),
      ),
    );
  }
}
