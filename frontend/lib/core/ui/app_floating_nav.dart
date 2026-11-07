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

/// Floating dark pill for phones. Every item is a round icon tile; only the
/// active one is a white tile with a visible label. Inactive items expose their
/// label to screen readers and as a hover tooltip instead.
class AppFloatingNav extends StatelessWidget {
  const AppFloatingNav({
    super.key,
    required this.items,
    required this.currentIndex,
    required this.onSelected,
  });

  /// Tiles are 48 dp round, the pill adds 8 dp on each side. Single-line label
  /// at any text scale (it ellipsizes), so the height does not depend on it.
  static const double height = 64;

  static double heightFor(TextScaler scaler) => height;

  final List<AppNavItem> items;
  final int currentIndex;
  final ValueChanged<int> onSelected;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.all(AppSpacing.sm),
        decoration: BoxDecoration(
          color: AppColors.navDark,
          borderRadius: BorderRadius.circular(AppRadius.pill),
          boxShadow: AppElevation.level2,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            for (var i = 0; i < items.length; i++) ...[
              if (i > 0) const SizedBox(width: AppSpacing.sm),
              i == currentIndex
                  ? Flexible(
                      child: _PillTile(
                        item: items[i],
                        selected: true,
                        onTap: () => onSelected(i),
                      ),
                    )
                  : _PillTile(
                      item: items[i],
                      selected: false,
                      onTap: () => onSelected(i),
                    ),
            ],
          ],
        ),
      );
}

class _PillTile extends StatelessWidget {
  const _PillTile({
    required this.item,
    required this.selected,
    required this.onTap,
  });

  final AppNavItem item;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final tile = Material(
      color: selected ? AppColors.surface : AppColors.navDarkTile,
      borderRadius: BorderRadius.circular(AppRadius.pill),
      child: InkWell(
        borderRadius: BorderRadius.circular(AppRadius.pill),
        onTap: onTap,
        child: ConstrainedBox(
          constraints: const BoxConstraints(
              minWidth: AppSpacing.touch, minHeight: AppSpacing.touch),
          child: Padding(
            padding: EdgeInsets.symmetric(
                horizontal: selected ? AppSpacing.lg : AppSpacing.md),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(selected ? item.selectedIcon : item.icon,
                    color: selected ? AppColors.navDark : AppColors.onNavDark),
                if (selected) ...[
                  const SizedBox(width: AppSpacing.sm),
                  Flexible(
                    child: Text(
                      item.label,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AppTypography.label
                          .copyWith(color: AppColors.navDark),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
    return Semantics(
      button: true,
      selected: selected,
      label: item.label,
      hint: selected ? 'выбрано' : null,
      excludeSemantics: true,
      child: selected
          ? tile
          : Tooltip(
              message: item.label, excludeFromSemantics: true, child: tile),
    );
  }
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
