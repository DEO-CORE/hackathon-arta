import 'package:flutter/material.dart';

import '../theme/app_tokens.dart';

class AppNavItem {
  const AppNavItem({
    required this.label,
    required this.icon,
    required this.selectedIcon,
    required this.route,
  });

  final String label;
  final IconData icon;
  final IconData selectedIcon;
  final String route;
}

/// Floating pill nav for phones: icon above a visible label on every item.
class AppFloatingNav extends StatelessWidget {
  const AppFloatingNav({
    super.key,
    required this.items,
    required this.currentIndex,
    required this.onSelected,
  });

  /// Pill height (items are 56 dp high).
  static const double height = 72;

  /// Pill height at a text scale: labels wrap to two lines above ~140%, so a
  /// fixed 72 would let the nav cover the end of a scrolled list.
  static double heightFor(TextScaler scaler) {
    final label = scaler.scale(16); // caption line height is 16
    final lines = scaler.scale(10) > 14 ? 2 : 1;
    final tile = 4 + 24 + lines * label + 4;
    return (tile < 56 ? 56 : tile) + AppSpacing.sm * 2;
  }

  final List<AppNavItem> items;
  final int currentIndex;
  final ValueChanged<int> onSelected;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.all(AppSpacing.sm),
        decoration: BoxDecoration(
          color: AppColors.navSurface,
          borderRadius: BorderRadius.circular(AppRadius.pill),
          border: Border.all(color: AppColors.border),
          boxShadow: AppElevation.level2,
        ),
        child: Row(
          children: [
            for (var i = 0; i < items.length; i++)
              Expanded(
                child: _NavTile(
                  item: items[i],
                  selected: i == currentIndex,
                  onTap: () => onSelected(i),
                  vertical: true,
                ),
              ),
          ],
        ),
      );
}

/// Left rail for laptop widths: same items, same active tile.
class AppNavRail extends StatelessWidget {
  const AppNavRail({
    super.key,
    required this.items,
    required this.currentIndex,
    required this.onSelected,
  });

  final List<AppNavItem> items;
  final int currentIndex;
  final ValueChanged<int> onSelected;

  @override
  Widget build(BuildContext context) => Container(
        width: 96,
        padding: const EdgeInsets.symmetric(
            vertical: AppSpacing.lg, horizontal: AppSpacing.sm),
        decoration: const BoxDecoration(
          color: AppColors.navSurface,
          border: Border(right: BorderSide(color: AppColors.border)),
        ),
        child: SafeArea(
          child: Column(
            children: [
              for (var i = 0; i < items.length; i++)
                Padding(
                  padding: const EdgeInsets.only(bottom: AppSpacing.sm),
                  child: _NavTile(
                    item: items[i],
                    selected: i == currentIndex,
                    onTap: () => onSelected(i),
                    vertical: true,
                  ),
                ),
            ],
          ),
        ),
      );
}

class _NavTile extends StatelessWidget {
  const _NavTile({
    required this.item,
    required this.selected,
    required this.onTap,
    required this.vertical,
  });

  final AppNavItem item;
  final bool selected;
  final VoidCallback onTap;
  final bool vertical;

  @override
  Widget build(BuildContext context) => Semantics(
        button: true,
        selected: selected,
        label: item.label,
        hint: selected ? 'выбрано' : null,
        excludeSemantics: true,
        child: Material(
          color: selected ? AppColors.surface : Colors.transparent,
          borderRadius: BorderRadius.circular(AppRadius.lg),
          child: InkWell(
            borderRadius: BorderRadius.circular(AppRadius.lg),
            onTap: onTap,
            child: ConstrainedBox(
              constraints: const BoxConstraints(minHeight: 56),
              child: Padding(
                padding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.xs, vertical: AppSpacing.xs),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(selected ? item.selectedIcon : item.icon,
                        color: selected
                            ? AppColors.text
                            : AppColors.textSecondary),
                    Text(
                      item.label,
                      maxLines: 2,
                      textAlign: TextAlign.center,
                      overflow: TextOverflow.ellipsis,
                      style: AppTypography.caption.copyWith(
                        color:
                            selected ? AppColors.text : AppColors.textSecondary,
                        fontWeight:
                            selected ? FontWeight.w500 : FontWeight.w400,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      );
}
