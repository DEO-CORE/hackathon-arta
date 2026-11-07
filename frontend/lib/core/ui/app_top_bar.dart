import 'package:flutter/material.dart';

import '../theme/app_tokens.dart';

/// Rounded-square 48 dp icon button with a mandatory accessible name.
class AppIconTile extends StatelessWidget {
  const AppIconTile({
    super.key,
    required this.icon,
    required this.tooltip,
    required this.onPressed,
  });

  final IconData icon;
  final String tooltip;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) => Tooltip(
        message: tooltip,
        child: Semantics(
          button: true,
          enabled: onPressed != null,
          label: tooltip,
          excludeSemantics: true,
          child: Material(
            color: AppColors.surface,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(AppRadius.iconTile),
              side: const BorderSide(color: AppColors.border),
            ),
            child: InkWell(
              borderRadius: BorderRadius.circular(AppRadius.iconTile),
              onTap: onPressed,
              child: SizedBox(
                width: AppSpacing.touch,
                height: AppSpacing.touch,
                child: Icon(icon,
                    color: onPressed == null
                        ? AppColors.textSecondary
                        : AppColors.text),
              ),
            ),
          ),
        ),
      );
}

/// Transparent top bar: back tile left, centred title, optional trailing tile.
/// The back tile shows when [onBack] is given or the route can pop.
class AppTopBar extends StatelessWidget implements PreferredSizeWidget {
  const AppTopBar({
    super.key,
    this.title,
    this.onBack,
    this.trailing,
    this.showBack,
  });

  final String? title;
  final VoidCallback? onBack;
  final Widget? trailing;
  final bool? showBack;

  @override
  Size get preferredSize => const Size.fromHeight(64);

  @override
  Widget build(BuildContext context) {
    final canPop = Navigator.maybeOf(context)?.canPop() ?? false;
    final back = showBack ?? (onBack != null || canPop);
    return SafeArea(
      bottom: false,
      child: SizedBox(
        height: preferredSize.height,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
          child: Row(
            children: [
              SizedBox(
                width: AppSpacing.touch,
                child: back
                    ? AppIconTile(
                        icon: Icons.arrow_back,
                        tooltip: 'Назад',
                        onPressed:
                            onBack ?? () => Navigator.of(context).maybePop(),
                      )
                    : null,
              ),
              Expanded(
                child: title == null
                    ? const SizedBox.shrink()
                    : Semantics(
                        header: true,
                        child: Text(
                          title!,
                          textAlign: TextAlign.center,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: AppTypography.title.copyWith(fontSize: 17),
                        ),
                      ),
              ),
              SizedBox(
                width: AppSpacing.touch,
                child: trailing,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
