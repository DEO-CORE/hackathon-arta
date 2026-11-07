import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:flutter/services.dart';

import '../../../core/config/app_config.dart';
import '../../../core/session/session.dart';
import '../../../core/theme/app_tokens.dart';
import '../../../core/ui/ui.dart';
import '../../../core/widgets/error_panel.dart';
import '../../../demo/demo_auth_repository.dart';
import '../providers/auth_providers.dart';
import 'auth_validators.dart';

class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _email = TextEditingController();
  final _password = TextEditingController();
  bool _showPassword = false;

  @override
  void dispose() {
    _email.dispose();
    _password.dispose();
    super.dispose();
  }

  void _submit() {
    if (ref.read(authFormProvider).submitting) return;
    if (!(_formKey.currentState?.validate() ?? false)) return;
    ref
        .read(authFormProvider.notifier)
        .login(_email.text.trim(), _password.text);
  }

  @override
  Widget build(BuildContext context) {
    final demo = ref.watch(appConfigProvider).useDemoData;
    // The demo account is synthetic: never offer to store it in the OS password
    // manager. Real accounts keep normal autofill (DEV-05).
    ref.listen(sessionProvider.select((s) => s.isAuthenticated), (_, authed) {
      if (demo && authed) TextInput.finishAutofillContext(shouldSave: false);
    });
    final form = ref.watch(authFormProvider);
    final expired = ref.watch(sessionProvider.select((s) => s.expired));
    final fieldErrors = form.error?.fieldErrors ?? const <String, String>{};
    return Scaffold(
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(
              AppSpacing.lg, AppSpacing.xxl, AppSpacing.lg, AppSpacing.xl),
          child: AppContentColumn(
            maxWidth: 420,
            child: Form(
              key: _formKey,
              autovalidateMode: AutovalidateMode.onUserInteraction,
              child: AutofillGroup(
                onDisposeAction: demo
                    ? AutofillContextAction.cancel
                    : AutofillContextAction.commit,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const AppBrandBlock(),
                    const SizedBox(height: AppSpacing.xl),
                    Text('Вход', style: AppTypography.headline),
                    const SizedBox(height: AppSpacing.lg),
                    if (expired && form.error == null) ...[
                      const Text('Сессия истекла. Войдите снова.'),
                      const SizedBox(height: AppSpacing.md),
                    ],
                    if (form.error != null) ...[
                      ErrorBanner(error: form.error!),
                      const SizedBox(height: AppSpacing.md),
                    ],
                    AppTextField(
                      label: 'Email',
                      controller: _email,
                      enabled: !form.submitting,
                      keyboardType: TextInputType.emailAddress,
                      autofillHints: demo ? null : const [AutofillHints.email],
                      textInputAction: TextInputAction.next,
                      errorText: fieldErrors['email'],
                      validator: validateEmail,
                    ),
                    const SizedBox(height: AppSpacing.lg),
                    AppTextField(
                      label: 'Пароль',
                      controller: _password,
                      enabled: !form.submitting,
                      obscureText: !_showPassword,
                      autofillHints:
                          demo ? null : const [AutofillHints.password],
                      textInputAction: TextInputAction.done,
                      onFieldSubmitted: (_) => _submit(),
                      errorText: fieldErrors['password'],
                      suffix: IconButton(
                        tooltip:
                            _showPassword ? 'Скрыть пароль' : 'Показать пароль',
                        icon: Icon(_showPassword
                            ? Icons.visibility_off
                            : Icons.visibility),
                        onPressed: () =>
                            setState(() => _showPassword = !_showPassword),
                      ),
                      validator: (v) =>
                          (v == null || v.isEmpty) ? 'Укажите пароль.' : null,
                    ),
                    const SizedBox(height: AppSpacing.xl),
                    AppButton(
                      label: 'Войти',
                      loading: form.submitting,
                      loadingLabel: 'Отправка…',
                      onPressed: _submit,
                    ),
                    const SizedBox(height: AppSpacing.sm),
                    AppButton(
                      label: 'Нет аккаунта? Зарегистрироваться',
                      kind: AppButtonKind.text,
                      onPressed: form.submitting
                          ? null
                          : () => context.go('/register'),
                    ),
                    if (demo) ...[
                      const SizedBox(height: AppSpacing.lg),
                      _DemoLoginBlock(
                        enabled: !form.submitting,
                        onFill: () {
                          _email.text = demoLoginEmail;
                          _password.text = demoLoginPassword;
                        },
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _DemoLoginBlock extends StatelessWidget {
  const _DemoLoginBlock({required this.enabled, required this.onFill});
  final bool enabled;
  final VoidCallback onFill;

  @override
  Widget build(BuildContext context) => AppCard(
        child: Row(
          children: [
            const Icon(Icons.science, color: AppColors.textSecondary),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              child: Text('Демо-вход: $demoLoginEmail / $demoLoginPassword',
                  key: const Key('demoCredentials'),
                  style: AppTypography.bodySmall),
            ),
            AppButton(
              label: 'Заполнить',
              kind: AppButtonKind.text,
              onPressed: enabled ? onFill : null,
            ),
          ],
        ),
      );
}
