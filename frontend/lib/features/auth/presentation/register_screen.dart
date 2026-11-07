import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/app_tokens.dart';
import '../../../core/ui/ui.dart';
import '../../../core/widgets/error_panel.dart';
import '../models/auth_models.dart';
import '../providers/auth_providers.dart';
import 'auth_validators.dart';

class RegisterScreen extends ConsumerStatefulWidget {
  const RegisterScreen({super.key});

  @override
  ConsumerState<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends ConsumerState<RegisterScreen> {
  final _formKey = GlobalKey<FormState>();
  final _email = TextEditingController();
  final _password = TextEditingController();
  final _orgName = TextEditingController();
  final _city = TextEditingController();
  UserRole _role = UserRole.enterprise;
  ActivityType _activity = ActivityType.garmentFactory;

  @override
  void dispose() {
    _email.dispose();
    _password.dispose();
    _orgName.dispose();
    _city.dispose();
    super.dispose();
  }

  // Role "admin" is never offered; buyer may be a workshop or a recycler.
  List<ActivityType> get _activities => _role == UserRole.enterprise
      ? const [
          ActivityType.garmentFactory,
          ActivityType.workshop,
          ActivityType.other,
        ]
      : const [ActivityType.workshop, ActivityType.recycler];

  void _submit() {
    if (ref.read(authFormProvider).submitting) return;
    if (!(_formKey.currentState?.validate() ?? false)) return;
    ref.read(authFormProvider.notifier).register(
          RegisterRequest(
            email: _email.text.trim(),
            password: _password.text,
            role: _role,
            organizationName: _orgName.text.trim(),
            city: _city.text.trim(),
            activityType: _activity,
          ),
        );
  }

  @override
  Widget build(BuildContext context) {
    final form = ref.watch(authFormProvider);
    final busy = form.submitting;
    final fe = form.error?.fieldErrors ?? const <String, String>{};
    return Scaffold(
      appBar: AppBar(title: const Text('Регистрация')),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(AppSpacing.lg),
          child: AppContentColumn(
            maxWidth: 420,
            child: Form(
              autovalidateMode: AutovalidateMode.onUserInteraction,
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  if (form.error != null) ...[
                    ErrorBanner(error: form.error!),
                    const SizedBox(height: AppSpacing.lg),
                  ],
                  DropdownButtonFormField<UserRole>(
                    initialValue: _role,
                    decoration: const InputDecoration(labelText: 'Роль'),
                    items: const [
                      DropdownMenuItem(
                        value: UserRole.enterprise,
                        child: Text('Предприятие'),
                      ),
                      DropdownMenuItem(
                        value: UserRole.buyer,
                        child: Text('Покупатель'),
                      ),
                    ],
                    onChanged: busy
                        ? null
                        : (v) => setState(() {
                              _role = v ?? _role;
                              _activity = _activities.first;
                            }),
                  ),
                  const SizedBox(height: AppSpacing.lg),
                  AppTextField(
                    controller: _email,
                    enabled: !busy,
                    keyboardType: TextInputType.emailAddress,
                    autofillHints: const [AutofillHints.email],
                    label: 'Email',
                    errorText: fe['email'],
                    validator: validateEmail,
                  ),
                  const SizedBox(height: AppSpacing.lg),
                  AppTextField(
                    controller: _password,
                    enabled: !busy,
                    obscureText: true,
                    autofillHints: const [AutofillHints.newPassword],
                    label: 'Пароль',
                    helper: 'От 10 символов',
                    errorText: fe['password'],
                    validator: validateNewPassword,
                  ),
                  const SizedBox(height: AppSpacing.lg),
                  AppTextField(
                    controller: _orgName,
                    enabled: !busy,
                    label: 'Название организации',
                    errorText: fe['organization.name'],
                    validator: (v) => validateRequired(v,
                        emptyMessage: 'Укажите название организации.'),
                  ),
                  const SizedBox(height: AppSpacing.lg),
                  AppTextField(
                    controller: _city,
                    enabled: !busy,
                    label: 'Город',
                    errorText: fe['organization.city'],
                    validator: (v) => validateRequired(v,
                        max: 100, emptyMessage: 'Укажите город.'),
                  ),
                  const SizedBox(height: AppSpacing.lg),
                  DropdownButtonFormField<ActivityType>(
                    key: ValueKey(_role),
                    initialValue: _activity,
                    decoration:
                        const InputDecoration(labelText: 'Вид деятельности'),
                    items: [
                      for (final a in _activities)
                        DropdownMenuItem(value: a, child: Text(a.label)),
                    ],
                    onChanged: busy
                        ? null
                        : (v) => setState(() => _activity = v ?? _activity),
                  ),
                  const SizedBox(height: AppSpacing.xl),
                  AppButton(
                    label: 'Зарегистрироваться',
                    loading: busy,
                    loadingLabel: 'Отправка…',
                    onPressed: _submit,
                  ),
                  AppButton(
                    label: 'Уже есть аккаунт? Войти',
                    kind: AppButtonKind.text,
                    onPressed: busy ? null : () => context.go('/login'),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
