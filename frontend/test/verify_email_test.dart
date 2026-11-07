import 'package:arta/core/config/app_config.dart';
import 'package:arta/core/network/api_exception.dart';
import 'package:arta/core/session/session.dart';
import 'package:arta/features/auth/data/auth_repository.dart';
import 'package:arta/features/auth/data/email_verification_repository.dart';
import 'package:arta/features/auth/models/auth_models.dart';
import 'package:arta/features/auth/presentation/login_screen.dart';
import 'package:arta/features/auth/presentation/verify_email_screen.dart';
import 'package:arta/features/auth/providers/auth_providers.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

class _Auth implements AuthRepository {
  int logins = 0;
  ApiException? failWith;

  @override
  Future<LoginResult> login(
      {required String email, required String password}) async {
    logins++;
    if (failWith != null) throw failWith!;
    throw StateError('not expected');
  }

  @override
  Future<void> register(RegisterRequest request) async {}
}

/// Production-like fake: 6 digits, sends email, no demo notice.
class _Codes implements EmailVerificationRepository {
  _Codes({this.sendError, this.verifyError});
  ApiException? sendError;
  ApiException? verifyError;
  final int? resendAfter = 60;
  int sends = 0;
  final verified = <String>[];

  @override
  int get codeLength => 6;
  @override
  bool get sendsEmail => true;
  @override
  String? get notice => null;

  @override
  Future<int?> send(String email) async {
    sends++;
    if (sendError != null) throw sendError!;
    return resendAfter;
  }

  @override
  Future<void> verify(String email, String code) async {
    verified.add(code);
    if (verifyError != null) throw verifyError!;
  }
}

ApiException _api(String code, int status, [Map<String, dynamic>? details]) =>
    ApiException(
        code: code, message: 'server', statusCode: status, details: details);

Future<ProviderContainer> _pump(
  WidgetTester tester, {
  required bool demo,
  EmailVerificationRepository? codes,
  _Auth? auth,
  double scale = 1,
  Size size = const Size(360, 720),
  String initial = '/verify-email',
  String? pendingEmail = 'seller@demo.arta',
}) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  final c = ProviderContainer(overrides: [
    appConfigProvider
        .overrideWithValue(AppConfig(apiBaseUrl: '', useDemoData: demo)),
    authRepositoryProvider.overrideWithValue(auth ?? _Auth()),
    if (codes != null)
      emailVerificationRepositoryProvider.overrideWithValue(codes),
    pendingEmailProvider.overrideWith((ref) => pendingEmail),
  ]);
  addTearDown(c.dispose);
  final router = GoRouter(initialLocation: initial, routes: [
    GoRoute(
        path: '/verify-email', builder: (_, __) => const VerifyEmailScreen()),
    GoRoute(path: '/login', builder: (_, __) => const LoginScreen()),
    GoRoute(
        path: '/register',
        builder: (_, __) => const Scaffold(body: Text('register-page'))),
  ]);
  addTearDown(router.dispose);
  await tester.pumpWidget(UncontrolledProviderScope(
    container: c,
    child: MaterialApp.router(
      routerConfig: router,
      builder: (ctx, w) => MediaQuery(
          data:
              MediaQuery.of(ctx).copyWith(textScaler: TextScaler.linear(scale)),
          child: w!),
    ),
  ));
  await tester.pump();
  await tester.pump();
  return c;
}

FilledButton _button(WidgetTester tester, String label) =>
    tester.widget<FilledButton>(find.widgetWithText(FilledButton, label));

Future<void> _type(WidgetTester tester, String text) async {
  await tester.enterText(find.byType(TextField), text);
  await tester.pump();
}

void main() {
  test('email is masked, countdown is m:ss', () {
    expect(maskEmail('seller@demo.arta'), 'se***@demo.arta');
    expect(maskEmail('a@b.kg'), 'a***@b.kg');
    expect(formatCountdown(60), '1:00');
    expect(formatCountdown(45), '0:45');
  });

  group('demo (USE_DEMO_DATA=true)', () {
    testWidgets('4 digits, demo notice, nothing claimed as sent, button gated',
        (tester) async {
      await _pump(tester, demo: true);
      expect(find.text('Подтвердите email'), findsOneWidget);
      expect(
          find.text('Демо: письмо не отправляется, код 7777'), findsOneWidget);
      expect(find.textContaining('Код отправлен'), findsNothing);
      expect(find.text('Код для se***@demo.arta'), findsOneWidget);
      expect(_button(tester, 'Подтвердить').onPressed, isNull);
      await _type(tester, '777');
      expect(_button(tester, 'Подтвердить').onPressed, isNull);
      await _type(tester, '77777'); // capped at 4
      expect(tester.widget<TextField>(find.byType(TextField)).controller!.text,
          '7777');
      expect(_button(tester, 'Подтвердить').onPressed, isNotNull);
    });

    testWidgets('7777 is accepted: login screen with the message, no sign-in',
        (tester) async {
      final auth = _Auth();
      final c = await _pump(tester, demo: true, auth: auth);
      await _type(tester, '7777');
      await tester.tap(find.text('Подтвердить'));
      await tester.pumpAndSettle(const Duration(seconds: 1));
      expect(find.text('Вход'), findsOneWidget);
      expect(find.text('Email подтверждён'), findsOneWidget);
      expect(find.widgetWithText(TextFormField, 'Email'), findsOneWidget);
      expect(find.text('seller@demo.arta'), findsWidgets); // prefilled
      expect(auth.logins, 0); // no auto sign-in
      expect(c.read(sessionProvider).isAuthenticated, isFalse);
      expect(c.read(pendingEmailProvider), isNull);
    });

    testWidgets('1234 is rejected and the user stays on the code screen',
        (tester) async {
      await _pump(tester, demo: true);
      await _type(tester, '1234');
      await tester.tap(find.text('Подтвердить'));
      await tester.pump();
      await tester.pump();
      expect(find.text('Неверный код.'), findsOneWidget);
      expect(find.text('Подтвердите email'), findsOneWidget);
      await _type(tester, '123');
      expect(find.text('Неверный код.'), findsNothing);
    });
  });

  group('production (API)', () {
    testWidgets('6 digits, no demo code anywhere, button gated, paste cleaned',
        (tester) async {
      final codes = _Codes();
      await _pump(tester, demo: false, codes: codes);
      expect(find.textContaining('7777'), findsNothing);
      expect(find.textContaining('Демо'), findsNothing);
      expect(find.text('Код отправлен на se***@demo.arta'), findsOneWidget);
      await _type(tester, '12345');
      expect(_button(tester, 'Подтвердить').onPressed, isNull);
      // Paste with separators and a prefix: only digits, capped at 6.
      await tester.enterText(find.byType(TextField), 'код 12 34 56 78');
      await tester.pump();
      expect(tester.widget<TextField>(find.byType(TextField)).controller!.text,
          '123456');
      expect(_button(tester, 'Подтвердить').onPressed, isNotNull);
      Clipboard.setData(const ClipboardData(text: '123456'));
    });

    testWidgets(
        '7777 is not special: it is sent to the server as a normal code',
        (tester) async {
      final codes = _Codes(verifyError: _api('INVALID_CODE', 409));
      await _pump(tester, demo: false, codes: codes);
      await _type(tester, '777777');
      await tester.tap(find.text('Подтвердить'));
      await tester.pump();
      await tester.pump();
      expect(codes.verified, ['777777']);
      expect(find.text('Неверный код.'), findsOneWidget);
    });

    testWidgets('INVALID_CODE shows attempts_left', (tester) async {
      final codes =
          _Codes(verifyError: _api('INVALID_CODE', 409, {'attempts_left': 3}));
      await _pump(tester, demo: false, codes: codes);
      await _type(tester, '111111');
      await tester.tap(find.text('Подтвердить'));
      await tester.pump();
      await tester.pump();
      expect(find.text('Неверный код. Осталось попыток: 3.'), findsOneWidget);
    });

    testWidgets('CODE_EXPIRED offers an immediate resend', (tester) async {
      final codes = _Codes(verifyError: _api('CODE_EXPIRED', 409));
      await _pump(tester, demo: false, codes: codes);
      expect(find.textContaining('через 1:00'), findsOneWidget);
      await _type(tester, '111111');
      await tester.tap(find.text('Подтвердить'));
      await tester.pump();
      await tester.pump();
      expect(find.text('Срок действия кода истёк. Отправьте код снова.'),
          findsOneWidget);
      expect(find.text('Отправить код снова'), findsOneWidget);
    });

    testWidgets('429 shows the wait time', (tester) async {
      final codes = _Codes(
          verifyError: _api('RATE_LIMITED', 429, {'retry_after_seconds': 900}));
      await _pump(tester, demo: false, codes: codes);
      await _type(tester, '111111');
      await tester.tap(find.text('Подтвердить'));
      await tester.pump();
      await tester.pump();
      expect(find.text('Слишком много попыток. Повторите через 900 с.'),
          findsOneWidget);
    });

    testWidgets('503 on send: honest message, no "sent", resend available',
        (tester) async {
      final codes = _Codes(sendError: _api('EMAIL_DELIVERY_UNAVAILABLE', 503));
      await _pump(tester, demo: false, codes: codes);
      expect(find.text('Отправка писем пока недоступна'), findsOneWidget);
      expect(find.textContaining('Код отправлен'), findsNothing);
      expect(find.textContaining('через'), findsNothing);
      expect(find.text('Отправить код снова'), findsOneWidget);
      codes.sendError = null;
      await tester.tap(find.text('Отправить код снова'));
      await tester.pump();
      await tester.pump();
      expect(codes.sends, 2);
      expect(find.text('Код отправлен на se***@demo.arta'), findsOneWidget);
    });

    testWidgets('resend timer: 60 s countdown, then the button, then restart',
        (tester) async {
      final codes = _Codes();
      await _pump(tester, demo: false, codes: codes);
      expect(codes.sends, 1);
      expect(find.text('Отправить код снова через 1:00'), findsOneWidget);
      await tester.pump(const Duration(seconds: 1));
      expect(find.text('Отправить код снова через 0:59'), findsOneWidget);
      await tester.pump(const Duration(seconds: 59));
      expect(find.textContaining('через'), findsNothing);
      await tester.tap(find.text('Отправить код снова'));
      await tester.pump();
      await tester.pump();
      expect(codes.sends, 2);
      expect(find.text('Отправить код снова через 1:00'), findsOneWidget);
    });

    testWidgets('200% text, 320 dp, 6 cells: no overflow', (tester) async {
      await _pump(tester,
          demo: false,
          codes: _Codes(
              verifyError: _api('INVALID_CODE', 409, {'attempts_left': 2})),
          scale: 2,
          size: const Size(320, 640));
      expect(tester.takeException(), isNull);
      await _type(tester, '123456');
      await tester.ensureVisible(find.text('Подтвердить'));
      await tester.tap(find.text('Подтвердить'));
      await tester.pump();
      await tester.pump();
      expect(tester.takeException(), isNull);
    });

    testWidgets('"Изменить email" returns to registration', (tester) async {
      final c = await _pump(tester, demo: false, codes: _Codes());
      await tester.tap(find.text('Изменить email'));
      await tester.pumpAndSettle(const Duration(seconds: 1));
      expect(find.text('register-page'), findsOneWidget);
      expect(c.read(pendingEmailProvider), isNull);
    });
  });

  testWidgets('login 403 EMAIL_NOT_CONFIRMED explains and leads to the code',
      (tester) async {
    final auth = _Auth()..failWith = _api('EMAIL_NOT_CONFIRMED', 403);
    final c = await _pump(tester,
        demo: false,
        codes: _Codes(),
        auth: auth,
        initial: '/login',
        pendingEmail: null);
    await tester.enterText(
        find.widgetWithText(TextFormField, 'Email'), 'a@b.kg');
    await tester.enterText(
        find.widgetWithText(TextFormField, 'Пароль'), 'secret-pass');
    await tester.pump();
    await tester.tap(find.text('Войти'));
    await tester.pump();
    await tester.pump();
    expect(find.text('Email не подтверждён. Подтвердите email, чтобы войти.'),
        findsOneWidget);
    await tester.tap(find.text('Подтвердить email'));
    await tester.pumpAndSettle(const Duration(seconds: 1));
    expect(find.text('Подтвердите email'), findsOneWidget);
    expect(c.read(pendingEmailProvider), 'a@b.kg');
  });
}
