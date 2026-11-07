import 'package:arta/core/config/app_config.dart';
import 'package:arta/demo/demo_auth_repository.dart';
import 'package:arta/features/auth/presentation/login_screen.dart';
import 'package:arta/features/materials/presentation/material_create_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/material_fakes.dart';

Future<void> _pumpLogin(WidgetTester tester, {required bool demo}) async {
  final c = ProviderContainer(overrides: [
    appConfigProvider
        .overrideWithValue(AppConfig(apiBaseUrl: '', useDemoData: demo)),
  ]);
  addTearDown(c.dispose);
  await tester.pumpWidget(UncontrolledProviderScope(
      container: c, child: const MaterialApp(home: LoginScreen())));
}

void main() {
  testWidgets('DEV-01: a field error clears as soon as the value is fixed',
      (tester) async {
    await _pumpLogin(tester, demo: false);
    await tester.tap(find.text('Войти'));
    await tester.pump();
    expect(find.text('Укажите email.'), findsOneWidget);
    await tester.enterText(find.widgetWithText(TextFormField, 'Email'), 'abc');
    await tester.pump();
    expect(find.text('Укажите email.'), findsNothing);
    expect(
        find.text('Введите email в формате name@example.com.'), findsOneWidget);
    await tester.enterText(
        find.widgetWithText(TextFormField, 'Email'), 'a@b.kg');
    await tester.pump();
    expect(
        find.text('Введите email в формате name@example.com.'), findsNothing);
    // The untouched password field keeps its error until the user edits it.
    expect(find.text('Укажите пароль.'), findsOneWidget);
  });

  testWidgets('DEV-01: material form error clears while typing',
      (tester) async {
    await pumpScreen(
        tester, makeContainer(RecordingRepo()), const MaterialCreateScreen());
    await tester.tap(find.text('Сохранить черновик'));
    await tester.pumpAndSettle();
    expect(find.text('Укажите название партии.'), findsOneWidget);
    await tester.enterText(
        find.widgetWithText(TextFormField, 'Название (обязательно)'), 'X');
    await tester.pump();
    expect(find.text('Укажите название партии.'), findsNothing);
  });

  testWidgets('DEV-03: photo block starts at the same left edge as the fields',
      (tester) async {
    await pumpScreen(
        tester, makeContainer(RecordingRepo()), const MaterialCreateScreen());
    final fieldLeft = tester
        .getTopLeft(
            find.widgetWithText(TextFormField, 'Название (обязательно)'))
        .dx;
    expect(tester.getTopLeft(find.text('Фото партии (до 5)')).dx, fieldLeft);
    expect(
        tester
            .getTopLeft(find.widgetWithText(OutlinedButton, 'Добавить фото'))
            .dx,
        fieldLeft);
  });

  testWidgets('DEV-05: demo login does not offer to save the password',
      (tester) async {
    await _pumpLogin(tester, demo: true);
    final group = tester.widget<AutofillGroup>(find.byType(AutofillGroup));
    expect(group.onDisposeAction, AutofillContextAction.cancel);
    for (final f in tester.widgetList<TextField>(find.byType(TextField))) {
      expect(f.autofillHints, isNull);
    }
    expect(find.text('Демо-вход: $demoLoginEmail / $demoLoginPassword'),
        findsOneWidget);
    await tester.tap(find.text('Заполнить'));
    await tester.pump();
    expect(find.text(demoLoginEmail), findsOneWidget);
  });

  testWidgets('DEV-05: real login keeps password-manager support',
      (tester) async {
    await _pumpLogin(tester, demo: false);
    final group = tester.widget<AutofillGroup>(find.byType(AutofillGroup));
    expect(group.onDisposeAction, AutofillContextAction.commit);
    final hints = tester
        .widgetList<TextField>(find.byType(TextField))
        .expand((f) => f.autofillHints ?? const <String>[])
        .toList();
    expect(hints, containsAll([AutofillHints.email, AutofillHints.password]));
    expect(find.textContaining('Демо-вход'), findsNothing);
  });

  testWidgets('password visibility toggle has an accessible name',
      (tester) async {
    await _pumpLogin(tester, demo: false);
    expect(find.byTooltip('Показать пароль'), findsOneWidget);
    await tester.tap(find.byTooltip('Показать пароль'));
    await tester.pump();
    expect(find.byTooltip('Скрыть пароль'), findsOneWidget);
  });
}
