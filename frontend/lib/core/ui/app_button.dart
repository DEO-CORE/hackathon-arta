import 'package:flutter/material.dart';

import '../theme/app_tokens.dart';

enum AppButtonKind { primary, secondary, text, destructive }

/// Button with a >= 48 px target. While [loading] it is disabled (blocks a
/// second submit) and shows a labelled spinner; [loadingLabel] replaces text.
class AppButton extends StatelessWidget {
  const AppButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.kind = AppButtonKind.primary,
    this.loading = false,
    this.loadingLabel,
    this.icon,
    this.autofocus = false,
  });

  final String label;
  final VoidCallback? onPressed;
  final AppButtonKind kind;
  final bool loading;
  final String? loadingLabel;
  final IconData? icon;
  final bool autofocus;

  @override
  Widget build(BuildContext context) {
    final handler = loading ? null : onPressed;
    final text = Text(loading ? (loadingLabel ?? label) : label);
    final Widget lead = loading
        ? const SizedBox(
            width: 18,
            height: 18,
            child: CircularProgressIndicator(
                strokeWidth: 2, semanticsLabel: 'Выполняется'),
          )
        : (icon != null ? Icon(icon, size: 18) : const SizedBox.shrink());
    final hasLead = loading || icon != null;
    final child = hasLead
        ? Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              lead,
              const SizedBox(width: AppSpacing.sm),
              Flexible(child: text),
            ],
          )
        : text;
    switch (kind) {
      case AppButtonKind.primary:
        return FilledButton(
            autofocus: autofocus, onPressed: handler, child: child);
      case AppButtonKind.destructive:
        return FilledButton(
          autofocus: autofocus,
          style: FilledButton.styleFrom(
            backgroundColor: AppColors.error,
            foregroundColor: AppColors.onError,
          ),
          onPressed: handler,
          child: child,
        );
      case AppButtonKind.secondary:
        return OutlinedButton(
            autofocus: autofocus, onPressed: handler, child: child);
      case AppButtonKind.text:
        return TextButton(
            autofocus: autofocus, onPressed: handler, child: child);
    }
  }
}
