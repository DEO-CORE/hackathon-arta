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
  LoginNotice? _notice;

  @override
  void initState() {
    super.initState();
    // One-shot message (for example "Email подтверждён"): keep it for this
    // screen instance and clear the shared state right away.
    _notice = ref.read(loginNoticeProvider);
    if (_notice?.email != null) _email.text = _notice!.email!;
    if (_notice != null) {
      Future.microtask(
          () => ref.read(loginNoticeProvider.notifier).state = null);
    }
  }

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
    return AppAuthBackground(
      child: Scaffold(
        backgroundColor: Colors.transparent,
        // Pinned primary action; disabled until the form can be valid.
        bottomNavigationBar: AppBottomBar(
          child: ListenableBuilder(
            listenable: Listenable.merge([_email, _password]),
            builder: (context, _) => AppButton(
              label: 'Войти',
              loading: form.submitting,
              loadingLabel: 'Отправка…',
              onPressed: validateEmail(_email.text) == null &&
                      _password.text.isNotEmpty
                  ? _submit
                  : null,
            ),
          ),
        ),
        body: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(
                AppSpacing.xl, AppSpacing.xl, AppSpacing.xl, AppSpacing.xl),
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
                      const AppBrandBlock(centered: true, tagline: false),
                      const SizedBox(height: AppSpacing.xl),
                      Text('Вход',
                          style: AppTypography.display
                              .copyWith(fontWeight: FontWeight.w700)),
                      const SizedBox(height: AppSpacing.xs),
                      Text('Войдите, чтобы продолжить',
                          style: AppTypography.body
                              .copyWith(color: AppColors.textSecondary)),
                      const SizedBox(height: AppSpacing.lg),
                      if (expired && form.error == null) ...[
                        const Text('Сессия истекла. Войдите снова.'),
                        const SizedBox(height: AppSpacing.md),
                      ],
                      if (_notice != null && form.error == null) ...[
                        Semantics(
                          liveRegion: true,
                          child: Row(
                            children: [
                              const Icon(Icons.check_circle,
                                  color: AppColors.success),
                              const SizedBox(width: AppSpacing.sm),
                              Expanded(child: Text(_notice!.message)),
                            ],
                          ),
                        ),
                        const SizedBox(height: AppSpacing.md),
                      ],
                      if (form.error?.code == 'EMAIL_NOT_CONFIRMED') ...[
                        const Text(
                            'Email не подтверждён. Подтвердите email, чтобы войти.'),
                        AppButton(
                          label: 'Подтвердить email',
                          kind: AppButtonKind.secondary,
                          onPressed: () {
                            ref.read(pendingEmailProvider.notifier).state =
                                _email.text.trim();
                            context.go('/verify-email');
                          },
                        ),
                        const SizedBox(height: AppSpacing.md),
                      ] else if (form.error != null) ...[
                        ErrorBanner(error: form.error!),
                        const SizedBox(height: AppSpacing.md),
                      ],
                      AppTextField(
                        label: 'Email',
                        prefixIcon: Icons.mail,
                        helper: 'Адрес, указанный при регистрации.',
                        controller: _email,
                        enabled: !form.submitting,
                        keyboardType: TextInputType.emailAddress,
                        autofillHints:
                            demo ? null : const [AutofillHints.email],
                        textInputAction: TextInputAction.next,
                        errorText: fieldErrors['email'],
                        validator: validateEmail,
                      ),
                      const SizedBox(height: AppSpacing.lg),
                      AppTextField(
                        label: 'Пароль',
                        prefixIcon: Icons.lock,
                        controller: _password,
                        enabled: !form.submitting,
                        obscureText: !_showPassword,
                        autofillHints:
                            demo ? null : const [AutofillHints.password],
                        textInputAction: TextInputAction.done,
                        onFieldSubmitted: (_) => _submit(),
                        errorText: fieldErrors['password'],
                        suffix: IconButton(
                          tooltip: _showPassword
                              ? 'Скрыть пароль'
                              : 'Показать пароль',
                          icon: Icon(_showPassword
                              ? Icons.visibility_off
                              : Icons.visibility),
                          onPressed: () =>
                              setState(() => _showPassword = !_showPassword),
                        ),
                        validator: (v) =>
                            (v == null || v.isEmpty) ? 'Укажите пароль.' : null,
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
                        const SizedBox(height: AppSpacing.sm),
                        const _OrDivider(),
                        const SizedBox(height: AppSpacing.md),
                        _DemoLoginBlock(
                          enabled: !form.submitting,
                          onFill: () {
                            _email.text = demoLoginEmail;
                            _password.text = demoLoginPassword;
                          },
                          onFillOther: (email, password) {
                            _email.text = email;
                            _password.text = password;
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
      ),
    );
  }
}

class _OrDivider extends StatelessWidget {
  const _OrDivider();

  @override
  Widget build(BuildContext context) => Row(
        children: [
          const Expanded(child: Divider()),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
            child: Text('или', style: AppTypography.caption),
          ),
          const Expanded(child: Divider()),
        ],
      );
}

class _DemoLoginBlock extends StatelessWidget {
  const _DemoLoginBlock({
    required this.enabled,
    required this.onFill,
    required this.onFillOther,
  });
  final bool enabled;
  final VoidCallback onFill;
  final void Function(String email, String password) onFillOther;

  @override
  Widget build(BuildContext context) => AppCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
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
            _OtherAccount(
              text: 'Покупатель: $demoBuyerEmail / $demoBuyerPassword',
              label: 'Заполнить: покупатель',
              enabled: enabled,
              onFill: () => onFillOther(demoBuyerEmail, demoBuyerPassword),
            ),
            _OtherAccount(
              text: 'Переработчик: $demoRecyclerEmail / $demoRecyclerPassword',
              label: 'Заполнить: переработчик',
              enabled: enabled,
              onFill: () =>
                  onFillOther(demoRecyclerEmail, demoRecyclerPassword),
            ),
          ],
        ),
      );
}

class _OtherAccount extends StatelessWidget {
  const _OtherAccount({
    required this.text,
    required this.label,
    required this.enabled,
    required this.onFill,
  });
  final String text;
  final String label;
  final bool enabled;
  final VoidCallback onFill;

  @override
  Widget build(BuildContext context) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: AppSpacing.sm),
          Text(text, style: AppTypography.bodySmall),
          AppButton(
            label: label,
            kind: AppButtonKind.text,
            onPressed: enabled ? onFill : null,
          ),
        ],
      );
}
