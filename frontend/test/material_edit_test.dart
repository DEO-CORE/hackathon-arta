import 'dart:async';

import 'package:arta/core/network/api_exception.dart';
import 'package:arta/features/materials/presentation/material_edit_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/material_fakes.dart';

Finder _field(String text) => find.widgetWithText(TextFormField, text);

void main() {
  testWidgets('PATCH carries version and only the changed field',
      (tester) async {
    final repo = RecordingRepo();
    await pumpScreen(tester, makeContainer(repo),
        const MaterialEditScreen(materialId: 'm1'));
    await tester.enterText(_field('Бишкек'), 'Ош');
    await tester.tap(find.text('Сохранить'));
    await tester.pumpAndSettle();
    expect(repo.patchCalls, 1);
    expect(repo.lastPatch!.toJson(), {'version': 5, 'city': 'Ош'});
  });

  testWidgets('mass written differently (10 vs 10.000) is not a change',
      (tester) async {
    final repo = RecordingRepo();
    await pumpScreen(tester, makeContainer(repo),
        const MaterialEditScreen(materialId: 'm1'));
    await tester.enterText(_field('10.000'), '10');
    await tester.tap(find.text('Сохранить'));
    await tester.pumpAndSettle();
    expect(repo.patchCalls, 0);
    expect(find.text('Нет изменений.'), findsOneWidget);
  });

  testWidgets('cleared optional price is sent as explicit null',
      (tester) async {
    final repo = RecordingRepo();
    await pumpScreen(tester, makeContainer(repo),
        const MaterialEditScreen(materialId: 'm1'));
    await tester.enterText(_field('45.00'), '');
    await tester.tap(find.text('Сохранить'));
    await tester.pumpAndSettle();
    expect(repo.lastPatch!.toJson(), {'version': 5, 'price_per_kg': null});
  });

  testWidgets('409 VERSION_CONFLICT shows current_version, keeps input',
      (tester) async {
    final repo = RecordingRepo()
      ..patchError = const ApiException(
          code: 'VERSION_CONFLICT',
          message: 'raw',
          statusCode: 409,
          details: {'current_version': 7});
    await pumpScreen(tester, makeContainer(repo),
        const MaterialEditScreen(materialId: 'm1'));
    await tester.enterText(_field('Демо-партия'), 'Моё имя');
    await tester.enterText(_field('Бишкек'), 'Ош');
    await tester.tap(find.text('Сохранить'));
    await tester.pumpAndSettle();
    expect(find.textContaining('версия на сервере: 7'), findsOneWidget);
    expect(find.textContaining('VERSION_CONFLICT'), findsNothing);
    expect(_field('Моё имя'), findsOneWidget);
    expect(_field('Ош'), findsOneWidget);
    // Refresh does not wipe typed values.
    await tester.tap(find.text('Обновить данные'));
    await tester.pumpAndSettle();
    expect(_field('Моё имя'), findsOneWidget);
    expect(_field('Ош'), findsOneWidget);
  });

  testWidgets('after refresh the next save uses the fresh version',
      (tester) async {
    final repo = RecordingRepo()
      ..patchError = const ApiException(
          code: 'VERSION_CONFLICT',
          message: 'x',
          statusCode: 409,
          details: {'current_version': 9});
    await pumpScreen(tester, makeContainer(repo),
        const MaterialEditScreen(materialId: 'm1'));
    await tester.enterText(_field('Бишкек'), 'Ош');
    await tester.tap(find.text('Сохранить'));
    await tester.pumpAndSettle();
    repo
      ..patchError = null
      ..serverItem = fakeItem('m1', version: 9);
    await tester.tap(find.text('Обновить данные'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Сохранить'));
    await tester.pumpAndSettle();
    expect(repo.lastPatch!.version, 9);
  });

  testWidgets('ACTIVE_OBLIGATIONS shows plain text without raw codes',
      (tester) async {
    final repo = RecordingRepo()
      ..patchError = const ApiException(
          code: 'ACTIVE_OBLIGATIONS',
          message: 'raw',
          statusCode: 409,
          details: {
            'blocked_fields': ['city', 'total_kg']
          });
    await pumpScreen(tester, makeContainer(repo),
        const MaterialEditScreen(materialId: 'm1'));
    await tester.enterText(_field('Бишкек'), 'Ош');
    await tester.tap(find.text('Сохранить'));
    await tester.pumpAndSettle();
    expect(find.textContaining('Нельзя изменить: есть активные заявки.'),
        findsOneWidget);
    expect(find.textContaining('ACTIVE_OBLIGATIONS'), findsNothing);
    expect(_field('Ош'), findsOneWidget);
  });

  testWidgets('save is blocked while PATCH is in flight', (tester) async {
    final repo = RecordingRepo()..patchGate = Completer();
    await pumpScreen(tester, makeContainer(repo),
        const MaterialEditScreen(materialId: 'm1'));
    await tester.enterText(_field('Бишкек'), 'Ош');
    await tester.tap(find.text('Сохранить'));
    await tester.pump();
    final btn = tester
        .widget<FilledButton>(find.widgetWithText(FilledButton, 'Сохранение…'));
    expect(btn.onPressed, isNull);
    await tester.tap(find.text('Сохранение…'), warnIfMissed: false);
    await tester.pump();
    expect(repo.patchCalls, 1);
    repo.patchGate!.complete();
    await tester.pumpAndSettle();
    expect(repo.patchCalls, 1);
  });
}
