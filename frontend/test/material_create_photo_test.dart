import 'dart:async';

import 'package:arta/core/network/api_exception.dart';
import 'package:arta/features/materials/presentation/material_create_screen.dart';
import 'package:arta/features/materials/models/material_rules.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/material_fakes.dart';

const _bad = ApiException(
    code: 'UNSUPPORTED_IMAGE', message: 'Файл не подходит', statusCode: 422);

void main() {
  testWidgets('photo failure keeps form data and does not lose the draft',
      (tester) async {
    final repo = RecordingRepo()..uploadError = _bad;
    await pumpScreen(tester, makeContainer(repo), const MaterialCreateScreen());
    await fillCreateForm(tester);
    await tester.tap(find.text('Добавить фото'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Сохранить черновик'));
    await tester.pumpAndSettle();
    expect(repo.createCalls, 1);
    expect(find.textContaining('Файл не подходит'), findsOneWidget);
    expect(find.textContaining('Введённые данные сохранены'), findsOneWidget);
    expect(find.widgetWithText(TextFormField, 'Хлопковые обрезки'),
        findsOneWidget);
    expect(find.widgetWithText(TextFormField, '12,5'), findsOneWidget);
  });

  testWidgets('retry upload creates no second draft', (tester) async {
    final repo = RecordingRepo()..uploadError = _bad;
    await pumpScreen(tester, makeContainer(repo), const MaterialCreateScreen());
    await fillCreateForm(tester);
    await tester.tap(find.text('Добавить фото'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Сохранить черновик'));
    await tester.pumpAndSettle();
    for (var i = 0; i < 3; i++) {
      await tester.tap(find.text('Повторить загрузку фото'));
      await tester.pumpAndSettle();
    }
    expect(repo.createCalls, 1);
    expect(repo.uploadCalls, 4);
  });

  testWidgets('form is locked after the draft exists', (tester) async {
    final repo = RecordingRepo()..uploadError = _bad;
    await pumpScreen(tester, makeContainer(repo), const MaterialCreateScreen());
    await fillCreateForm(tester);
    await tester.tap(find.text('Добавить фото'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Сохранить черновик'));
    await tester.pumpAndSettle();
    final name = tester.widget<TextField>(find
        .descendant(
            of: find.widgetWithText(TextFormField, 'Хлопковые обрезки'),
            matching: find.byType(TextField))
        .first);
    expect(name.enabled, isFalse);
  });

  testWidgets('already uploaded photos are not re-sent on retry',
      (tester) async {
    final repo = RecordingRepo();
    final picker = StubPicker([
      PickedPhoto(name: 'a.jpg', bytes: jpegBytes(1)),
      PickedPhoto(name: 'b.jpg', bytes: jpegBytes(2)),
    ]);
    await pumpScreen(tester, makeContainer(repo, picker: picker),
        const MaterialCreateScreen(),
        size: const Size(400, 2400));
    await fillCreateForm(tester);
    await tester.tap(find.text('Добавить фото'));
    await tester.pumpAndSettle();
    repo.uploadError = _bad;
    await tester.tap(find.text('Сохранить черновик'));
    await tester.pumpAndSettle();
    expect(repo.uploadCalls, 2);
    expect(repo.createCalls, 1);
  });

  testWidgets('create 422 does not mark a draft as created', (tester) async {
    final repo = RecordingRepo()
      ..createError = const ApiException(
          code: 'VALIDATION_ERROR',
          message: 'Проверьте поля.',
          statusCode: 422);
    await pumpScreen(tester, makeContainer(repo), const MaterialCreateScreen());
    await fillCreateForm(tester);
    await tester.tap(find.text('Сохранить черновик'));
    await tester.pumpAndSettle();
    expect(find.text('Сохранить черновик'), findsOneWidget);
    expect(find.text('Повторить загрузку фото'), findsNothing);
    await tester.tap(find.text('Сохранить черновик'));
    await tester.pumpAndSettle();
    expect(repo.createCalls, 2);
  });

  testWidgets('button is disabled and labelled while saving', (tester) async {
    final repo = RecordingRepo()..createGate = Completer();
    await pumpScreen(tester, makeContainer(repo), const MaterialCreateScreen());
    await fillCreateForm(tester);
    await tester.tap(find.text('Сохранить черновик'));
    await tester.pump();
    final btn = tester
        .widget<FilledButton>(find.widgetWithText(FilledButton, 'Сохранение…'));
    expect(btn.onPressed, isNull);
    await tester.tap(find.text('Сохранение…'), warnIfMissed: false);
    await tester.pump();
    expect(repo.createCalls, 1);
    // photo add is blocked while saving
    final add = tester.widget<OutlinedButton>(
        find.widgetWithText(OutlinedButton, 'Добавить фото'));
    expect(add.onPressed, isNull);
  });
}
