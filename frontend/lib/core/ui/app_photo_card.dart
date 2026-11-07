import 'package:flutter/material.dart';

import '../theme/app_tokens.dart';

/// Photo-led card: 4:3 photo, status pill top-left, info panel below with an
/// "open" arrow tile. The panel is under the photo, not over it, so long
/// Russian text never covers the image or overflows at large text scales.
/// One tap target with a combined semantics label.
class AppPhotoCard extends StatelessWidget {
  const AppPhotoCard({
    super.key,
    required this.photo,
    required this.title,
    required this.meta,
    required this.highlight,
    required this.onTap,
    this.badge,
    this.semanticsLabel,
  });

  /// Photo or placeholder widget; it is cropped to the 4:3 box.
  final Widget photo;
  final String title;
  final String meta;

  /// Key figure line, for example "Свободно: 45 кг" (server values only).
  final String highlight;
  final Widget? badge;
  final VoidCallback onTap;
  final String? semanticsLabel;

  @override
  Widget build(BuildContext context) => Semantics(
        button: true,
        label: semanticsLabel ?? '$title, $meta, $highlight',
        excludeSemantics: true,
        child: Material(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(AppRadius.card),
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            onTap: onTap,
            child: LayoutBuilder(builder: (context, c) {
              final h = c.maxWidth * 3 / 4;
              return Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Stack(
                    children: [
                      SizedBox(
                        width: c.maxWidth,
                        height: h,
                        child: ClipRect(
                          child: OverflowBox(
                            maxWidth: c.maxWidth,
                            maxHeight: c.maxWidth,
                            child: photo,
                          ),
                        ),
                      ),
                      if (badge != null)
                        Positioned(
                            top: AppSpacing.md,
                            left: AppSpacing.md,
                            child: badge!),
                    ],
                  ),
                  Padding(
                    padding: const EdgeInsets.all(AppSpacing.md),
                    child: Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(title,
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                  style: AppTypography.title),
                              Text(meta,
                                  maxLines: 4,
                                  overflow: TextOverflow.ellipsis,
                                  style: AppTypography.bodySmall.copyWith(
                                      color: AppColors.textSecondary)),
                              Text(highlight, style: AppTypography.label),
                            ],
                          ),
                        ),
                        const SizedBox(width: AppSpacing.sm),
                        const SizedBox.square(
                          dimension: AppSpacing.touch,
                          child: DecoratedBox(
                            decoration: BoxDecoration(
                              color: AppColors.primary,
                              borderRadius: BorderRadius.all(
                                  Radius.circular(AppRadius.iconTile)),
                            ),
                            child: Icon(Icons.arrow_outward,
                                color: AppColors.onPrimary),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              );
            }),
          ),
        ),
      );
}
