import 'package:flutter/material.dart';

import '../theme/app_tokens.dart';

/// Static placeholder block (no animation, so reduced-motion safe).
class AppSkeleton extends StatelessWidget {
  const AppSkeleton({super.key, this.height = 16, this.width});

  final double height;
  final double? width;

  @override
  Widget build(BuildContext context) => Container(
        height: height,
        width: width,
        decoration: BoxDecoration(
          color: AppColors.border,
          borderRadius: BorderRadius.circular(AppRadius.sm),
        ),
      );
}

/// List placeholder; announces loading once instead of per block.
class AppSkeletonList extends StatelessWidget {
  const AppSkeletonList({super.key, this.count = 4});

  final int count;

  @override
  Widget build(BuildContext context) => Semantics(
        label: 'Загрузка…',
        liveRegion: true,
        child: ExcludeSemantics(
          child: Column(
            children: [
              for (var i = 0; i < count; i++)
                const Padding(
                  padding: EdgeInsets.only(bottom: AppSpacing.md),
                  child: _SkeletonRow(),
                ),
            ],
          ),
        ),
      );
}

class _SkeletonRow extends StatelessWidget {
  const _SkeletonRow();

  @override
  Widget build(BuildContext context) => const DecoratedBox(
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.all(Radius.circular(AppRadius.md)),
          border: Border.fromBorderSide(BorderSide(color: AppColors.border)),
        ),
        child: Padding(
          padding: EdgeInsets.all(AppSpacing.lg),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              AppSkeleton(height: 18, width: 180),
              SizedBox(height: AppSpacing.sm),
              AppSkeleton(height: 14),
              SizedBox(height: AppSpacing.xs),
              AppSkeleton(height: 14, width: 120),
            ],
          ),
        ),
      );
}
