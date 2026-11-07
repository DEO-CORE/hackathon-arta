import 'dart:async';

import 'package:arta/core/network/api_exception.dart';
import 'package:arta/core/session/session.dart';
import 'package:arta/features/auth/data/auth_repository.dart';
import 'package:arta/features/auth/models/auth_models.dart';
import 'package:arta/features/auth/presentation/login_screen.dart';
import 'package:arta/features/auth/providers/auth_providers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

class FakeAuthRepository implements AuthRepository {
  int loginCalls = 0;
  Completer<LoginResult>? pending;
  ApiException? failWith;

  @override
  Future<LoginResult> login({required String email, required String password}) {
    loginCalls++;
    if (failWith != null) return Future.error(failWith!);
    pending = Completer<LoginResult>();
    return pending!.future;
  }

  @override
  Future<void> register(RegisterRequest request) async {}
}

Future<ProviderContainer> pumpLogin(
  WidgetTester tester,
  FakeAuthRepository repo,
) async {
  final container = ProviderContainer(
    overrides: [authRepositoryProvider.overrideWithValue(repo)],
  );
  addTearDown(container.dispose);
  await tester.pumpWidget(
    UncontrolledProviderScope(
      container: container,
      child: const MaterialApp(home: LoginScreen()),
    ),
  );
  return container;
}

void main() {
  testWidgets('empty form shows validation and does not call the repository',
      (tester) async {
    final repo = FakeAuthRepository();
    await pumpLogin(tester, repo);

    // The submit button is disabled until the form can be valid.
    final button = tester.widget<FilledButton>(find.byType(FilledButton));
    expect(button.onPressed, isNull);
    await tester.tap(find.text('Войти').last, warnIfMissed: false);
    await tester.pump();
    expect(repo.loginCalls, 0);

    // Validation messages appear once the user touches and clears a field.
    await tester.enterText(find.widgetWithText(TextFormField, 'Email'), 'a');
    await tester.enterText(find.widgetWithText(TextFormField, 'Email'), '');
    await tester.enterText(find.widgetWithText(TextFormField, 'Пароль'), 'a');
    await tester.enterText(find.widgetWithText(TextFormField, 'Пароль'), '');
    await tester.pump();
    expect(find.text('Укажите email.'), findsOneWidget);
    expect(find.text('Укажите пароль.'), findsOneWidget);
    expect(repo.loginCalls, 0);
  });

  testWidgets('rejects malformed email', (tester) async {
    final repo = FakeAuthRepository();
    await pumpLogin(tester, repo);

    await tester.enterText(find.widgetWithText(TextFormField, 'Email'), 'abc');
    await tester.enterText(find.widgetWithText(TextFormField, 'Пароль'), 'x');
    await tester.pump();
    await tester.tap(find.text('Войти').last, warnIfMissed: false);
    await tester.pump();

    expect(
        find.text('Введите email в формате name@example.com.'), findsOneWidget);
    expect(repo.loginCalls, 0);
  });

  testWidgets('blocks a second submit while the request is in flight',
      (tester) async {
    final repo = FakeAuthRepository();
    final container = await pumpLogin(tester, repo);

    await tester.enterText(
        find.widgetWithText(TextFormField, 'Email'), 'a@b.kg');
    await tester.enterText(
        find.widgetWithText(TextFormField, 'Пароль'), 'secret');
    await tester.pump(); // re-enables the submit button
    await tester.tap(find.text('Войти').last);
    await tester.pump();

    expect(find.text('Отправка…'), findsOneWidget);
    final button = tester.widget<FilledButton>(find.byType(FilledButton));
    expect(button.onPressed, isNull);

    // Direct controller call must be ignored too, not only the disabled button.
    await container.read(authFormProvider.notifier).login('a@b.kg', 'secret');
    expect(repo.loginCalls, 1);

    repo.pending!.complete(
      const LoginResult(
        accessToken: 't',
        user: AuthUser(
          id: '1',
          email: 'a@b.kg',
          role: UserRole.buyer,
          organizationId: '2',
          active: true,
        ),
      ),
    );
    await tester.pump();
    expect(container.read(sessionProvider).isAuthenticated, isTrue);
  });

  testWidgets('shows the envelope message and request id on server error',
      (tester) async {
    final repo = FakeAuthRepository()
      ..failWith = const ApiException(
        code: 'INTERNAL_ERROR',
        message: 'Что-то пошло не так. Повторите позже.',
        statusCode: 500,
        requestId: 'req-123',
      );
    await pumpLogin(tester, repo);

    await tester.enterText(
        find.widgetWithText(TextFormField, 'Email'), 'a@b.kg');
    await tester.enterText(
        find.widgetWithText(TextFormField, 'Пароль'), 'secret');
    await tester.pump(); // re-enables the submit button
    await tester.tap(find.text('Войти').last);
    await tester.pumpAndSettle();

    expect(find.text('Что-то пошло не так. Повторите позже.'), findsOneWidget);
    expect(find.text('Код обращения: req-123'), findsOneWidget);
    final button = tester.widget<FilledButton>(find.byType(FilledButton));
    expect(button.onPressed, isNotNull);
  });

  testWidgets('shows invalid credentials message without request id',
      (tester) async {
    final repo = FakeAuthRepository()
      ..failWith = const ApiException(
        code: 'INVALID_CREDENTIALS',
        message: 'Неверный email или пароль.',
        statusCode: 401,
        requestId: 'req-1',
      );
    await pumpLogin(tester, repo);

    await tester.enterText(
        find.widgetWithText(TextFormField, 'Email'), 'a@b.kg');
    await tester.enterText(
        find.widgetWithText(TextFormField, 'Пароль'), 'secret');
    await tester.pump(); // re-enables the submit button
    await tester.tap(find.text('Войти').last);
    await tester.pumpAndSettle();

    expect(find.text('Неверный email или пароль.'), findsOneWidget);
    expect(find.textContaining('Код обращения'), findsNothing);
  });
}
