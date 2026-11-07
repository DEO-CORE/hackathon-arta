import 'package:arta/app/app.dart';
import 'package:arta/app/router.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/material_fakes.dart';

Future<ProviderContainer> _app(WidgetTester tester, RecordingRepo repo) async {
  tester.view.physicalSize = const Size(400, 1600);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  final c = makeContainer(repo);
  await tester.pumpWidget(
      UncontrolledProviderScope(container: c, child: const ArtaApp()));
  await tester.pumpAndSettle();
  return c;
}

void main() {
  testWidgets('home -> Партии -> card -> Изменить', (tester) async {
    final item = fakeItem('m1', name: 'Хлопок А');
    final repo = RecordingRepo()
      ..items = [item]
      ..total = 1
      ..serverItem = item;
    await _app(tester, repo);

    await tester.tap(find.bySemanticsLabel('Партии'));
    await tester.pumpAndSettle();
    expect(find.text('Мои партии'), findsOneWidget);

    await tester.tap(find.text('Хлопок А'));
    await tester.pumpAndSettle();
    expect(repo.getCalls, 1);
    expect(find.text('Характеристики'), findsOneWidget);

    await tester.tap(find.text('Изменить'));
    await tester.pumpAndSettle();
    expect(find.text('Изменить партию'), findsOneWidget);
  });

  testWidgets('catalog -> Создать партию opens the form', (tester) async {
    final repo = RecordingRepo();
    await _app(tester, repo);
    await tester.tap(find.bySemanticsLabel('Партии'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Создать партию').first);
    await tester.pumpAndSettle();
    expect(find.text('Новая партия'), findsOneWidget);
  });

  testWidgets('unknown/forbidden object shows safe message', (tester) async {
    final repo = RecordingRepo();
    final c = await _app(tester, repo);
    c.read(routerProvider).go('/organization');
    await tester.pumpAndSettle();
    expect(find.textContaining('Traceback'), findsNothing);
  });

  testWidgets('/materials/:id/analysis opens the AI screen, starts nothing',
      (tester) async {
    final repo = RecordingRepo();
    final c = await _app(tester, repo);
    c.read(routerProvider).go('/materials/abc/analysis');
    await tester.pumpAndSettle();
    expect(find.text('Анализ ИИ'), findsOneWidget);
    expect(find.text('Для анализа нужно фото.'), findsOneWidget);
    expect(find.text('Скоро'), findsNothing);
    // Only the material is loaded; no analysis job is created on open.
    expect(repo.getCalls, 1);
    expect(repo.createCalls + repo.patchCalls + repo.uploadCalls, 0);
  });

  testWidgets('router exposes all Phase 2 material routes', (tester) async {
    final item = fakeItem('m1');
    final repo = RecordingRepo()..serverItem = item;
    final c = await _app(tester, repo);
    final r = c.read(routerProvider);
    r.go('/materials/new');
    await tester.pumpAndSettle();
    expect(find.text('Новая партия'), findsOneWidget);
    r.go('/materials/m1');
    await tester.pumpAndSettle();
    expect(find.text('Партия'), findsOneWidget);
    r.go('/materials/m1/edit');
    await tester.pumpAndSettle();
    expect(find.text('Изменить партию'), findsOneWidget);
  });
}
