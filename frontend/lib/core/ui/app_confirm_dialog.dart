import 'package:flutter/material.dart';

import 'app_button.dart';

/// Confirmation with consequences in [message]. Order: cancel (left), action
/// (right). Cancel is autofocused when [destructive] so Enter is safe.
class AppConfirmDialog extends StatelessWidget {
  const AppConfirmDialog({
    super.key,
    required this.title,
    required this.message,
    required this.confirmLabel,
    this.cancelLabel = 'Отмена',
    this.destructive = false,
    this.content,
  });

  final String title;
  final String message;
  final String confirmLabel;
  final String cancelLabel;
  final bool destructive;
  final Widget? content;

  static Future<bool> show(
    BuildContext context, {
    required String title,
    required String message,
    required String confirmLabel,
    String cancelLabel = 'Отмена',
    bool destructive = false,
  }) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AppConfirmDialog(
        title: title,
        message: message,
        confirmLabel: confirmLabel,
        cancelLabel: cancelLabel,
        destructive: destructive,
      ),
    );
    return ok == true;
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(title),
      content: content ?? Text(message),
      actions: [
        AppButton(
          label: cancelLabel,
          kind: AppButtonKind.text,
          autofocus: destructive,
          onPressed: () => Navigator.of(context).pop(false),
        ),
        AppButton(
          label: confirmLabel,
          kind: destructive ? AppButtonKind.destructive : AppButtonKind.primary,
          onPressed: () => Navigator.of(context).pop(true),
        ),
      ],
    );
  }
}
