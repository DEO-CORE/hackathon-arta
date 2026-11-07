import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/network/api_exception.dart';
import '../../../core/theme/app_tokens.dart';
import '../../../core/ui/ui.dart';
import '../../../core/widgets/error_panel.dart';
import '../providers/auth_providers.dart';

const defaultResendSeconds = 60;

/// "se***@demo.arta": enough to recognise the address, not to leak it.
String maskEmail(String email) {
  final at = email.indexOf('@');
  if (at <= 0) return email;
  final local = email.substring(0, at);
  final shown =
      local.length <= 2 ? local.substring(0, 1) : local.substring(0, 2);
  return '$shown***${email.substring(at)}';
}

String formatCountdown(int seconds) =>
    '${seconds ~/ 60}:${(seconds % 60).toString().padLeft(2, '0')}';

const emailDeliveryUnavailableText = 'Отправка писем пока недоступна';

/// User-facing text for the documented failures (api.md 23); anything else
/// keeps the server's safe message.
ApiException emailCodeError(ApiException e) {
  String? text;
  if (e.code == 'INVALID_CODE') {
    final left = e.details?['attempts_left'];
    text = left is int
        ? 'Неверный код. Осталось попыток: $left.'
        : 'Неверный код.';
  } else if (e.code == 'CODE_EXPIRED') {
    text = 'Срок действия кода истёк. Отправьте код снова.';
  } else if (e.code == 'EMAIL_DELIVERY_UNAVAILABLE' || e.statusCode == 503) {
    text = emailDeliveryUnavailableText;
  } else if (e.statusCode == 429) {
    final n = e.retryAfterSeconds;
    text = n == null
        ? 'Слишком много попыток. Повторите позже.'
        : 'Слишком много попыток. Повторите через $n с.';
  }
  if (text == null) return e;
  return ApiException(
      code: e.code,
      message: text,
      statusCode: e.statusCode,
      details: e.details,
      requestId: e.requestId,
      retryAfter: e.retryAfter);
}

enum _SendState { sending, sent, failed }

/// Step after registration (and after 403 EMAIL_NOT_CONFIRMED at login). A
/// successful confirmation returns to the login screen: no token is issued.
class VerifyEmailScreen extends ConsumerStatefulWidget {
  const VerifyEmailScreen({super.key});

  @override
  ConsumerState<VerifyEmailScreen> createState() => _VerifyEmailScreenState();
}

class _VerifyEmailScreenState extends ConsumerState<VerifyEmailScreen> {
  final _code = TextEditingController();
  final _focus = FocusNode();
  Timer? _timer;
  int _left = 0;
  bool _verifying = false;
  bool _leaving = false; // navigating away: do not redirect to /register
  _SendState _send = _SendState.sending;
  ApiException? _error;

  @override
  void initState() {
    super.initState();
    _code.addListener(() => setState(() => _error = null));
    WidgetsBinding.instance.addPostFrameCallback((_) => _sendCode());
  }

  @override
  void dispose() {
    _timer?.cancel();
    _code.dispose();
    _focus.dispose();
    super.dispose();
  }

  void _startTimer(int seconds) {
    _timer?.cancel();
    _left = seconds;
    if (seconds <= 0) return;
    _timer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (!mounted) return;
      setState(() => _left = _left > 0 ? _left - 1 : 0);
      if (_left == 0) t.cancel();
    });
  }

  Future<void> _sendCode() async {
    final email = ref.read(pendingEmailProvider);
    if (email == null) return;
    setState(() {
      _send = _SendState.sending;
      _error = null;
    });
    try {
      final after =
          await ref.read(emailVerificationRepositoryProvider).send(email);
      if (!mounted) return;
      setState(() => _send = _SendState.sent);
      _startTimer(after ?? defaultResendSeconds);
    } on ApiException catch (e) {
      if (!mounted) return;
      // Never claim "sent" after a failure; offer a retry (after the pause the
      // server asks for on 429).
      setState(() {
        _send = _SendState.failed;
        _error = emailCodeError(e);
      });
      _startTimer(e.statusCode == 429 ? (e.retryAfterSeconds ?? 0) : 0);
    }
  }

  Future<void> _verify() async {
    final email = ref.read(pendingEmailProvider);
    if (email == null || _verifying) return;
    setState(() {
      _verifying = true;
      _error = null;
    });
    try {
      await ref
          .read(emailVerificationRepositoryProvider)
          .verify(email, _code.text);
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() {
        _verifying = false;
        _error = emailCodeError(e);
        if (e.code == 'CODE_EXPIRED') {
          _timer?.cancel();
          _left = 0; // a new code is needed: offer resend now
        }
      });
      return;
    }
    if (!mounted) return;
    setState(() => _verifying = false);
    _leaving = true;
    ref.read(loginNoticeProvider.notifier).state =
        LoginNotice(message: 'Email подтверждён', email: email);
    ref.read(pendingEmailProvider.notifier).state = null;
    context.go('/login');
  }

  void _changeEmail() {
    _leaving = true;
    ref.read(pendingEmailProvider.notifier).state = null;
    context.go('/register');
  }

  @override
  Widget build(BuildContext context) {
    final email = ref.watch(pendingEmailProvider);
    if (email == null) {
      // Opened directly or after a restart: nothing to confirm.
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && !_leaving) context.go('/register');
      });
      return const Scaffold(body: SizedBox.shrink());
    }
    final repo = ref.watch(emailVerificationRepositoryProvider);
    final length = repo.codeLength;
    final complete = _code.text.length == length;
    final subtitle = !repo.sendsEmail
        ? 'Код для ${maskEmail(email)}'
        : switch (_send) {
            _SendState.sent => 'Код отправлен на ${maskEmail(email)}',
            _SendState.sending => 'Отправляем код на ${maskEmail(email)}…',
            _SendState.failed => 'Адрес: ${maskEmail(email)}',
          };
    return AppAuthBackground(
      child: Scaffold(
        backgroundColor: Colors.transparent,
        bottomNavigationBar: AppBottomBar(
          child: AppButton(
            label: 'Подтвердить',
            loading: _verifying,
            loadingLabel: 'Отправка…',
            onPressed: complete ? _verify : null,
          ),
        ),
        body: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(AppSpacing.xl),
            child: AppContentColumn(
              maxWidth: 420,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const AppBrandBlock(centered: true, tagline: false),
                  const SizedBox(height: AppSpacing.xl),
                  Text('Подтвердите email',
                      style: AppTypography.display
                          .copyWith(fontWeight: FontWeight.w700)),
                  const SizedBox(height: AppSpacing.xs),
                  Text(subtitle,
                      style: AppTypography.body
                          .copyWith(color: AppColors.textSecondary)),
                  const SizedBox(height: AppSpacing.lg),
                  if (repo.notice != null) ...[
                    _Notice(
                        icon: Icons.science,
                        text: repo.notice!,
                        key: const Key('demoCodeNotice')),
                    const SizedBox(height: AppSpacing.lg),
                  ],
                  _CodeCells(
                    controller: _code,
                    focus: _focus,
                    length: length,
                    enabled: !_verifying,
                    onSubmit: complete ? _verify : null,
                  ),
                  if (_error != null) ...[
                    const SizedBox(height: AppSpacing.md),
                    ErrorBanner(error: _error!),
                  ],
                  const SizedBox(height: AppSpacing.xl),
                  Center(
                    child: _left > 0
                        ? Text(
                            'Отправить код снова через ${formatCountdown(_left)}',
                            textAlign: TextAlign.center,
                            style: AppTypography.bodySmall
                                .copyWith(color: AppColors.textSecondary))
                        : AppButton(
                            label: 'Отправить код снова',
                            kind: AppButtonKind.text,
                            loading: _send == _SendState.sending,
                            onPressed: _verifying ? null : _sendCode,
                          ),
                  ),
                  AppButton(
                    label: 'Изменить email',
                    kind: AppButtonKind.text,
                    onPressed: _verifying ? null : _changeEmail,
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

class _Notice extends StatelessWidget {
  const _Notice({super.key, required this.icon, required this.text});
  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) => Semantics(
        container: true,
        liveRegion: true,
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: AppColors.neutralBg,
            borderRadius: BorderRadius.circular(AppRadius.iconTile),
          ),
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.md),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(icon, color: AppColors.neutral),
                const SizedBox(width: AppSpacing.sm),
                Expanded(child: Text(text, style: AppTypography.bodySmall)),
              ],
            ),
          ),
        ),
      );
}

/// Four digit cells driven by one invisible text field, so the numeric
/// keyboard, paste and the accessibility "text field" role all work.
class _CodeCells extends StatelessWidget {
  const _CodeCells({
    required this.controller,
    required this.focus,
    required this.length,
    required this.enabled,
    required this.onSubmit,
  });
  final TextEditingController controller;
  final FocusNode focus;
  final int length;
  final bool enabled;
  final VoidCallback? onSubmit;

  @override
  Widget build(BuildContext context) => ListenableBuilder(
        listenable: Listenable.merge([controller, focus]),
        builder: (context, _) {
          final text = controller.text;
          return Stack(
            children: [
              Row(
                children: [
                  for (var i = 0; i < length; i++) ...[
                    if (i > 0)
                      SizedBox(
                          width: length > 4 ? AppSpacing.sm : AppSpacing.md),
                    Expanded(
                      child: _Cell(
                        digit: i < text.length ? text[i] : '',
                        active: focus.hasFocus &&
                            i == text.length.clamp(0, length - 1),
                      ),
                    ),
                  ],
                ],
              ),
              Positioned.fill(
                child: Opacity(
                  opacity: 0,
                  child: Semantics(
                    textField: true,
                    label: 'Код подтверждения, цифр: $length',
                    child: TextField(
                      controller: controller,
                      focusNode: focus,
                      autofocus: true,
                      enabled: enabled,
                      keyboardType: TextInputType.number,
                      textInputAction: TextInputAction.done,
                      onSubmitted: (_) => onSubmit?.call(),
                      // Digits only, then the length cap: a pasted
                      // "12 34 56" or "code: 123456" becomes "123456".
                      inputFormatters: [
                        FilteringTextInputFormatter.digitsOnly,
                        LengthLimitingTextInputFormatter(length),
                      ],
                      autofillHints: const [AutofillHints.oneTimeCode],
                      decoration: const InputDecoration(counterText: ''),
                    ),
                  ),
                ),
              ),
            ],
          );
        },
      );
}

class _Cell extends StatelessWidget {
  const _Cell({required this.digit, required this.active});
  final String digit;
  final bool active;

  @override
  Widget build(BuildContext context) => Container(
        height: 56,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(AppRadius.pill),
          border: Border.all(
              color: active ? AppColors.focusRing : AppColors.controlBorder,
              width: active ? 2 : 1),
        ),
        child: Text(digit, style: AppTypography.headline),
      );
}
