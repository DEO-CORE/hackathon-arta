import 'package:flutter/material.dart';

import '../theme/app_tokens.dart';
import 'app_floating_nav.dart';

/// Soft page background: base colour with a primary-container wash at the top
/// right. Static (no animation).
class AppBackground extends StatelessWidget {
  const AppBackground({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) => DecoratedBox(
        decoration: const BoxDecoration(
          gradient: RadialGradient(
            center: Alignment.topRight,
            radius: 1.1,
            colors: [AppColors.backgroundWash, AppColors.background],
            stops: [0, 0.6],
          ),
        ),
        child: child,
      );
}

/// Wrapper (not a ShellRoute) for tab screens: background plus the floating
/// nav on phones or a left rail from [wideBreakpoint]. Navigation is delegated
/// to [onSelected]; routes and the auth guard are untouched.
class AppShell extends StatelessWidget {
  const AppShell({
    super.key,
    required this.items,
    required this.currentIndex,
    required this.onSelected,
    required this.child,
  });

  static const double wideBreakpoint = 600;

  final List<AppNavItem> items;
  final int currentIndex;
  final ValueChanged<int> onSelected;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final wide = MediaQuery.sizeOf(context).width >= wideBreakpoint;
    if (wide) {
      return AppBackground(
        child: Row(
          children: [
            AppNavRail(
                items: items,
                currentIndex: currentIndex,
                onSelected: onSelected),
            Expanded(child: child),
          ],
        ),
      );
    }
    final mq = MediaQuery.of(context);
    final navSpace =
        AppFloatingNav.heightFor(mq.textScaler) + AppSpacing.lg * 2;
    return AppBackground(
      child: Stack(
        children: [
          // Content sees the nav as extra bottom padding, so SafeArea and
          // scroll views keep the last item above it.
          MediaQuery(
            data: mq.copyWith(
              padding:
                  mq.padding.copyWith(bottom: mq.padding.bottom + navSpace),
            ),
            child: child,
          ),
          Positioned(
            left: AppSpacing.lg,
            right: AppSpacing.lg,
            bottom: AppSpacing.lg + mq.padding.bottom,
            child: Center(
              child: ConstrainedBox(
                constraints:
                    const BoxConstraints(maxWidth: AppSpacing.contentMax),
                child: AppFloatingNav(
                  items: items,
                  currentIndex: currentIndex,
                  onSelected: onSelected,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
