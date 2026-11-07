import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:flutter/services.dart';

import '../../../core/config/app_config.dart';
import '../../../core/session/session.dart';
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
      appBar: AppBar(title: const Text('ARTA')),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 420),
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
                    Text(
                      'Вход',
                      style: Theme.of(context).textTheme.headlineSmall,
                    ),
                    const SizedBox(height: 16),
                    if (expired && form.error == null) ...[
                      const Text('Сессия истекла. Войдите снова.'),
                      const SizedBox(height: 12),
                    ],
                    if (demo) ...[
                      Text('Демо-вход: $demoLoginEmail / $demoLoginPassword',
                          key: const Key('demoCredentials')),
                      Align(
                        alignment: Alignment.centerLeft,
                        child: TextButton(
                          onPressed: form.submitting
                              ? null
                              : () {
                                  _email.text = demoLoginEmail;
                                  _password.text = demoLoginPassword;
                                },
                          child: const Text('Заполнить'),
                        ),
                      ),
                    ],
                    if (form.error != null) ...[
                      ErrorBanner(error: form.error!),
                      const SizedBox(height: 12),
                    ],
                    TextFormField(
                      controller: _email,
                      enabled: !form.submitting,
                      keyboardType: TextInputType.emailAddress,
                      autofillHints: demo ? null : const [AutofillHints.email],
                      textInputAction: TextInputAction.next,
                      decoration: InputDecoration(
                        labelText: 'Email',
                        errorText: fieldErrors['email'],
                      ),
                      validator: validateEmail,
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: _password,
                      enabled: !form.submitting,
                      obscureText: !_showPassword,
                      autofillHints:
                          demo ? null : const [AutofillHints.password],
                      textInputAction: TextInputAction.done,
                      onFieldSubmitted: (_) => _submit(),
                      decoration: InputDecoration(
                        labelText: 'Пароль',
                        errorText: fieldErrors['password'],
                        suffixIcon: IconButton(
                          tooltip: _showPassword
                              ? 'Скрыть пароль'
                              : 'Показать пароль',
                          icon: Icon(_showPassword
                              ? Icons.visibility_off
                              : Icons.visibility),
                          onPressed: () =>
                              setState(() => _showPassword = !_showPassword),
                        ),
                      ),
                      validator: (v) =>
                          (v == null || v.isEmpty) ? 'Укажите пароль.' : null,
                    ),
                    const SizedBox(height: 20),
                    FilledButton(
                      onPressed: form.submitting ? null : _submit,
                      child: form.submitting
                          ? const Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                SizedBox(
                                  width: 18,
                                  height: 18,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    semanticsLabel: 'Отправка',
                                  ),
                                ),
                                SizedBox(width: 8),
                                Text('Отправка…'),
                              ],
                            )
                          : const Text('Войти'),
                    ),
                    TextButton(
                      onPressed: form.submitting
                          ? null
                          : () => context.go('/register'),
                      child: const Text('Нет аккаунта? Зарегистрироваться'),
                    ),
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
