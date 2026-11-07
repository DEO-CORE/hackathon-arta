import 'package:flutter/material.dart';

import '../theme/app_tokens.dart';

/// Text field with an always-visible label above the input, helper text and
/// the error under the field (via the form validator / [errorText]).
class AppTextField extends StatelessWidget {
  const AppTextField({
    super.key,
    required this.label,
    this.controller,
    this.helper,
    this.errorText,
    this.validator,
    this.keyboardType,
    this.obscureText = false,
    this.enabled = true,
    this.maxLines = 1,
    this.focusNode,
    this.onChanged,
    this.suffixText,
    this.suffix,
    this.prefixIcon,
    this.autovalidateMode,
    this.autofillHints,
    this.textInputAction,
    this.onFieldSubmitted,
  });

  final String label;
  final TextEditingController? controller;
  final String? helper;
  final String? errorText;
  final FormFieldValidator<String>? validator;
  final TextInputType? keyboardType;
  final bool obscureText;
  final bool enabled;
  final int maxLines;
  final FocusNode? focusNode;
  final ValueChanged<String>? onChanged;
  final String? suffixText;
  final Widget? suffix;
  final IconData? prefixIcon;
  final AutovalidateMode? autovalidateMode;
  final Iterable<String>? autofillHints;
  final TextInputAction? textInputAction;
  final ValueChanged<String>? onFieldSubmitted;

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      controller: controller,
      focusNode: focusNode,
      enabled: enabled,
      obscureText: obscureText,
      maxLines: maxLines,
      keyboardType: keyboardType,
      validator: validator,
      onChanged: onChanged,
      autovalidateMode: autovalidateMode,
      autofillHints: autofillHints,
      textInputAction: textInputAction,
      onFieldSubmitted: onFieldSubmitted,
      style: AppTypography.body,
      decoration: InputDecoration(
        labelText: label,
        floatingLabelBehavior: FloatingLabelBehavior.always,
        helperText: helper,
        helperMaxLines: 3,
        errorText: errorText,
        errorMaxLines: 3,
        suffixText: suffixText,
        suffixIcon: suffix,
        prefixIcon:
            prefixIcon == null ? null : Icon(prefixIcon, color: AppColors.text),
        contentPadding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.lg, vertical: AppSpacing.md),
      ),
    );
  }
}
