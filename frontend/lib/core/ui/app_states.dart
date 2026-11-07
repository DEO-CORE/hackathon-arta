import 'package:flutter/material.dart';

import '../theme/app_tokens.dart';
import 'app_button.dart';

class AppEmptyState extends StatelessWidget {
  const AppEmptyState({
    super.key,
    required this.title,
    this.message,
    this.icon = Icons.inbox_outlined,
    this.actionLabel,
    this.onAction,
  });

  final String title;
  final String? message;
  final IconData icon;
  final String? actionLabel;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) => _StateBody(
        icon: icon,
        iconColor: AppColors.textSecondary,
        title: title,
        message: message,
        actionLabel: actionLabel,
        onAction: onAction,
      );
}

/// Error with an optional retry action. Pass the safe server message as-is.
class AppErrorState extends StatelessWidget {
  const AppErrorState({
    super.key,
    required this.message,
    this.title = 'Что-то пошло не так',
    this.onRetry,
    this.retryLabel = 'Повторить',
  });

  final String title;
  final String message;
  final VoidCallback? onRetry;
  final String retryLabel;

  @override
  Widget build(BuildContext context) => Semantics(
        liveRegion: true,
        child: _StateBody(
          icon: Icons.error_outline,
          iconColor: AppColors.error,
          title: title,
          message: message,
          actionLabel: onRetry == null ? null : retryLabel,
          onAction: onRetry,
          secondaryAction: true,
        ),
      );
}

class _StateBody extends StatelessWidget {
  const _StateBody({
    required this.icon,
    required this.iconColor,
    required this.title,
    this.message,
    this.actionLabel,
    this.onAction,
    this.secondaryAction = false,
  });

  final IconData icon;
  final Color iconColor;
  final String title;
  final String? message;
  final String? actionLabel;
  final VoidCallback? onAction;
  final bool secondaryAction;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.xl),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 420),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 40, color: iconColor),
              const SizedBox(height: AppSpacing.md),
              Text(title,
                  textAlign: TextAlign.center, style: AppTypography.title),
              if (message != null) ...[
                const SizedBox(height: AppSpacing.sm),
                Text(message!,
                    textAlign: TextAlign.center,
                    style: AppTypography.bodySmall
                        .copyWith(color: AppColors.textSecondary)),
              ],
              if (actionLabel != null) ...[
                const SizedBox(height: AppSpacing.lg),
                AppButton(
                  label: actionLabel!,
                  onPressed: onAction,
                  kind: secondaryAction
                      ? AppButtonKind.secondary
                      : AppButtonKind.primary,
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
