import 'dart:async';

import 'package:arta/core/network/api_exception.dart';
import 'package:arta/features/auth/models/auth_models.dart';
import 'package:arta/features/materials/models/material_enums.dart';
import 'package:arta/features/materials/models/material_models.dart';
import 'package:arta/features/materials/presentation/catalog_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/material_fakes.dart';

Future<void> _pump(WidgetTester tester, RecordingRepo repo,
    {UserRole role = UserRole.enterprise, bool settle = true}) async {
  tester.view.physicalSize = const Size(400, 9000);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  final c = makeContainer(repo, role: role);
  await tester.pumpWidget(UncontrolledProviderScope(
      container: c, child: const MaterialApp(home: CatalogScreen())));
  if (settle) {
    await tester.pumpAndSettle();
  } else {
    await tester.pump();
  }
}

void main() {
  testWidgets('loading state shows a progress indicator, no list or empty text',
      (tester) async {
    final repo = RecordingRepo()..listGate = Completer();
    await _pump(tester, repo, settle: false);
    await tester.pump();
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    expect(find.text('Партий пока нет. Добавьте первую.'), findsNothing);
    expect(find.text('Повторить'), findsNothing);
  });

  testWidgets('empty state: owner gets CTA, buyer gets none', (tester) async {
    await _pump(tester, RecordingRepo());
    expect(find.text('Партий пока нет. Добавьте первую.'), findsOneWidget);
    expect(find.widgetWithText(FilledButton, 'Создать партию'), findsOneWidget);
  });

  testWidgets('buyer sees no create button and no status filter',
      (tester) async {
    await _pump(tester, RecordingRepo(), role: UserRole.buyer);
    expect(find.text('Пока нет опубликованных партий.'), findsOneWidget);
    expect(find.text('Создать партию'), findsNothing);
    expect(find.byType(ChoiceChip), findsNothing);
  });

  testWidgets('error state shows retry and retry reloads', (tester) async {
    final repo = RecordingRepo()
      ..listError = const ApiException(
          code: 'INTERNAL_ERROR',
          message: 'Что-то пошло не так. Повторите позже.',
          statusCode: 500,
          requestId: 'req-1');
    await _pump(tester, repo);
    expect(find.text('Повторить'), findsOneWidget);
    expect(find.text('Партий пока нет. Добавьте первую.'), findsNothing);
    final before = repo.listCalls;
    repo
      ..listError = null
      ..items = [fakeItem('a')]
      ..total = 1;
    await tester.tap(find.text('Повторить'));
    await tester.pumpAndSettle();
    expect(repo.listCalls, before + 1);
    expect(find.text('Демо-партия'), findsOneWidget);
    expect(find.text('Повторить'), findsNothing);
  });

  testWidgets('success: card shows decimals as received with units',
      (tester) async {
    final repo = RecordingRepo()
      ..items = [fakeItem('a')]
      ..total = 1;
    await _pump(tester, repo);
    expect(find.text('Масса: 10.000 кг'), findsOneWidget);
    expect(find.text('45.00 KGS/кг'), findsOneWidget);
    expect(find.text('Черновик'), findsWidgets);
  });

  testWidgets('status filter requests that status and can be reset',
      (tester) async {
    final repo = RecordingRepo()
      ..items = [
        fakeItem('d', name: 'Черн'),
        fakeItem('v', name: 'Дост', status: MaterialStatus.available),
      ]
      ..total = 2;
    await _pump(tester, repo);
    expect(find.text('Черн'), findsOneWidget);
    expect(find.text('Дост'), findsOneWidget);

    await tester.tap(find.widgetWithText(ChoiceChip, 'Доступно'));
    await tester.pumpAndSettle();
    expect(repo.lastStatus, MaterialStatus.available);
    expect(find.text('Дост'), findsOneWidget);
    expect(find.text('Черн'), findsNothing);

    await tester.tap(find.widgetWithText(ChoiceChip, 'Все'));
    await tester.pumpAndSettle();
    expect(repo.lastStatus, isNull);
    expect(find.text('Черн'), findsOneWidget);
  });

  testWidgets('filter with no results offers reset, not "create first"',
      (tester) async {
    final repo = RecordingRepo()
      ..items = [fakeItem('d')]
      ..total = 1;
    await _pump(tester, repo);
    await tester.scrollUntilVisible(
        find.widgetWithText(ChoiceChip, 'В архиве'), 100,
        scrollable: find.byType(Scrollable).first);
    await tester.ensureVisible(find.widgetWithText(ChoiceChip, 'В архиве'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(ChoiceChip, 'В архиве'));
    await tester.pumpAndSettle();
    expect(find.text('Ничего не найдено. Измените фильтры.'), findsOneWidget);
    expect(find.text('Партий пока нет. Добавьте первую.'), findsNothing);
    await tester.tap(find.text('Сбросить фильтры'));
    await tester.pumpAndSettle();
    expect(find.text('Демо-партия'), findsOneWidget);
  });

  testWidgets('"Показать ещё" appends page 2 without duplicates',
      (tester) async {
    final repo = RecordingRepo()
      ..items = [
        for (var i = 0; i < 25; i++) fakeItem('id$i', name: 'Партия $i')
      ]
      ..total = 25;
    await _pump(tester, repo);
    expect(find.textContaining('Партия '), findsNWidgets(20));
    await tester.ensureVisible(find.text('Показать ещё'));
    await tester.tap(find.text('Показать ещё'));
    await tester.pumpAndSettle();
    expect(find.textContaining('Партия '), findsNWidgets(25));
    for (var i = 0; i < 25; i++) {
      expect(find.text('Партия $i'), findsOneWidget, reason: 'item $i');
    }
    expect(find.text('Показать ещё'), findsNothing);
  });

  testWidgets('load-more failure keeps loaded items and offers retry',
      (tester) async {
    final repo = RecordingRepo()
      ..items = [
        for (var i = 0; i < 25; i++) fakeItem('id$i', name: 'Партия $i')
      ]
      ..total = 25;
    await _pump(tester, repo);
    repo.listError = ApiException.network();
    await tester.ensureVisible(find.text('Показать ещё'));
    await tester.tap(find.text('Показать ещё'));
    await tester.pumpAndSettle();
    expect(find.text('Партия 0'), findsOneWidget);
    expect(find.text('Повторить'), findsOneWidget);
    repo.listError = null;
    await tester.tap(find.text('Повторить'));
    await tester.pumpAndSettle();
    expect(find.textContaining('Партия '), findsNWidgets(25));
  });

  testWidgets('unknown status renders neutral label, not a crash',
      (tester) async {
    final repo = RecordingRepo()
      ..items = [
        MaterialItem(
            id: 'u',
            name: 'Странная',
            status: MaterialStatus.parse('from_future'),
            version: 1,
            availableKg: '1.000',
            images: const [])
      ]
      ..total = 1;
    await _pump(tester, repo);
    expect(find.text('Статус неизвестен'), findsWidgets);
    expect(find.text('Город не указан'), findsOneWidget);
  });

  // RED (bug QA-P2-01): MaterialStatusChip overflows its row on a 400 px
  // wide phone for long labels ("Статус неизвестен", "Частично распределено").
  testWidgets('long status labels do not overflow the catalog card',
      (tester) async {
    final repo = RecordingRepo()
      ..items = [
        fakeItem('p',
            name: 'Частичная', status: MaterialStatus.partiallyAllocated)
      ]
      ..total = 1;
    await _pump(tester, repo);
    expect(find.text('Частично распределено'), findsWidgets);
    expect(tester.takeException(), isNull);
  });
}
