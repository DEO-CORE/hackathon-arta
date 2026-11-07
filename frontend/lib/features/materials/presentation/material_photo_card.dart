import 'package:flutter/material.dart';

import '../../../core/ui/ui.dart';
import '../../../core/format/mass_format.dart';
import '../models/material_enums.dart';
import '../models/material_models.dart';
import 'material_photo.dart';
import 'status_chip.dart';

/// Catalog card for one batch; display only, all values come from the API.
class MaterialPhotoCard extends StatelessWidget {
  const MaterialPhotoCard({super.key, required this.item, required this.onTap});

  final MaterialItem item;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final type = item.materialType?.label;
    final cond = item.condition?.label;
    final typeLine =
        [if (type != null) type, if (cond != null) cond].join(' · ');
    final city = item.city ?? 'Город не указан';
    final price = item.pricePerKg == null
        ? 'Цена не указана'
        : '${item.pricePerKg} KGS/кг';
    final meta = [
      if (typeLine.isNotEmpty) typeLine,
      '$city · $price',
      if (item.organizationName != null) item.organizationName!,
    ].join('\n');
    final highlight = item.status == MaterialStatus.draft
        ? 'Масса: ${formatKg(item.balance?.totalKg ?? item.availableKg)}'
        : 'Свободно: ${formatKg(item.availableKg)}';
    return AppPhotoCard(
      title: item.name,
      meta: meta,
      highlight: highlight,
      semanticsLabel:
          'Партия ${item.name}, ${item.status.label}, свободно ${formatKg(item.availableKg)}, $city',
      badge: MaterialStatusChip(status: item.status),
      onTap: onTap,
      photo: LayoutBuilder(
        builder: (context, c) => MaterialPhoto(
          materialId: item.id,
          imageId: item.images.isEmpty ? null : item.images.first.id,
          label: 'Фото партии ${item.name}',
          size: c.maxWidth,
        ),
      ),
    );
  }
}
