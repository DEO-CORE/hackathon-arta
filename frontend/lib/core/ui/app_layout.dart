import 'package:flutter/material.dart';

import '../theme/app_tokens.dart';

/// Top-aligned, horizontally centred content column. Screens must not centre
/// vertically: that created the dead zone between app bar and content.
class AppContentColumn extends StatelessWidget {
  const AppContentColumn({
    super.key,
    required this.child,
    this.maxWidth = AppSpacing.contentMax,
  });

  final Widget child;
  final double maxWidth;

  @override
  Widget build(BuildContext context) => Align(
        alignment: Alignment.topCenter,
        child: ConstrainedBox(
          constraints: BoxConstraints(maxWidth: maxWidth),
          child: child,
        ),
      );
}

/// Pinned bottom bar with safe-area inset for the screen's single primary
/// action. Use as `Scaffold.bottomNavigationBar`.
class AppBottomBar extends StatelessWidget {
  const AppBottomBar({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) => DecoratedBox(
        decoration: const BoxDecoration(
          color: AppColors.surface,
          border: Border(top: BorderSide(color: AppColors.border)),
          boxShadow: AppElevation.level2,
        ),
        child: SafeArea(
          top: false,
          child: Align(
            alignment: Alignment.topCenter,
            heightFactor: 1,
            child: ConstrainedBox(
              constraints:
                  const BoxConstraints(maxWidth: AppSpacing.contentMax),
              child: Padding(
                padding: const EdgeInsets.all(AppSpacing.lg),
                child: child,
              ),
            ),
          ),
        ),
      );
}

/// Text wordmark: no logo file exists, so none is invented.
class AppBrandBlock extends StatelessWidget {
  const AppBrandBlock({super.key});

  @override
  Widget build(BuildContext context) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('ARTA',
              style: AppTypography.display.copyWith(
                  fontSize: 28, height: 36 / 28, fontWeight: FontWeight.w700)),
          Text(
              'Платформа учёта и повторного использования текстильных остатков',
              style: AppTypography.bodySmall
                  .copyWith(color: AppColors.textSecondary)),
        ],
      );
}
