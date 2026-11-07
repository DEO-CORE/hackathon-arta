import 'package:arta/app/app.dart';
import 'package:arta/core/session/session.dart';
import 'package:arta/core/ui/ui.dart';
import 'package:arta/features/auth/models/auth_models.dart';
import 'package:arta/features/home/presentation/home_screen.dart';
import 'package:arta/features/materials/models/material_enums.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/material_fakes.dart';

Future<ProviderContainer> _app(
  WidgetTester tester,
  RecordingRepo repo, {
  UserRole role = UserRole.enterprise,
  double scale = 1,
  Size size = const Size(360, 800),
}) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  tester.platformDispatcher.textScaleFactorTestValue = scale;
  addTearDown(tester.view.reset);
  addTearDown(tester.platformDispatcher.clearAllTestValues);
  final c = makeContainer(repo, role: role);
  await tester.pumpWidget(
      UncontrolledProviderScope(container: c, child: const ArtaApp()));
  await tester.pumpAndSettle();
  return c;
}

void main() {
  test('nextStepItem prefers an incomplete draft, else the first item', () {
    final draft = fakeItem('d'); // no photo, not confirmed
    final avail = fakeItem('a', status: MaterialStatus.available);
    expect(nextStepItem([avail, draft])!.id, 'd');
    expect(nextStepItem([avail])!.id, 'a');
    expect(nextStepItem(const []), isNull);
    expect(initialsOf('Демо швейная фабрика'), 'ДШ');
    expect(initialsOf(''), '?');
  });

  testWidgets('no batches: empty state with a working create button',
      (tester) async {
    await _app(tester, RecordingRepo());
    expect(find.text('Здравствуйте,'), findsOneWidget);
    expect(find.text('Партий пока нет. Добавьте первую.'), findsOneWidget);
    expect(find.byType(AppPhotoCard), findsNothing);
    expect(find.text('Здесь появятся ваши партии.'), findsOneWidget);
    await tester.tap(find.text('Создать партию'));
    await tester.pumpAndSettle();
    expect(find.text('Новая партия'), findsOneWidget);
  });

  testWidgets('draft: next-step card shows what is left; button opens it',
      (tester) async {
    final item = fakeItem('m1', name: 'Хлопковые обрезки');
    final repo = RecordingRepo()
      ..items = [item]
      ..total = 1
      ..serverItem = item;
    await _app(tester, repo);
    expect(find.text('Следующий шаг'), findsOneWidget);
    expect(find.text('Осталось: фото, подтверждение'), findsOneWidget);
    expect(find.text('Черновик'), findsWidgets); // badge on card and carousel
    await tester.tap(find.text('Открыть партию'));
    await tester.pumpAndSettle();
    expect(find.text('Характеристики'), findsOneWidget);
  });

  testWidgets('non-draft: shows the last batch with the free mass',
      (tester) async {
    final repo = RecordingRepo()
      ..items = [fakeItem('a', status: MaterialStatus.available)]
      ..total = 1;
    await _app(tester, repo);
    expect(find.text('Последняя партия'), findsOneWidget);
    expect(find.text('Следующий шаг'), findsNothing);
    expect(find.text('Свободно: 10 кг'), findsWidgets);
  });

  testWidgets('carousel lists batches; a card opens its page', (tester) async {
    final items = [
      for (var i = 0; i < 3; i++) fakeItem('id$i', name: 'Партия $i'),
    ];
    final repo = RecordingRepo()
      ..items = items
      ..total = 3
      ..serverItem = items[1];
    await _app(tester, repo);
    expect(find.byType(AppPhotoCard), findsNWidgets(3));
    expect(find.text('Ваши партии'), findsOneWidget);
    await tester.ensureVisible(find.byType(AppPhotoCard).first);
    await tester.tap(find.byType(AppPhotoCard).first);
    await tester.pumpAndSettle();
    expect(find.text('Характеристики'), findsOneWidget);
  });

  testWidgets('no search stub; the filter button opens the catalog',
      (tester) async {
    final repo = RecordingRepo()
      ..items = [fakeItem('a')]
      ..total = 1;
    await _app(tester, repo);
    expect(find.byTooltip('Поиск'), findsNothing);
    await tester.ensureVisible(find.byTooltip('Фильтры'));
    await tester.tap(find.byTooltip('Фильтры'));
    await tester.pumpAndSettle();
    expect(find.text('Мои партии'), findsOneWidget);
  });

  testWidgets('buyer: no filter button', (tester) async {
    final repo = RecordingRepo()
      ..items = [fakeItem('a', status: MaterialStatus.available)]
      ..total = 1;
    await _app(tester, repo, role: UserRole.buyer);
    expect(find.byTooltip('Фильтры'), findsNothing);
    expect(find.text('Роль: Покупатель'), findsOneWidget);
  });

  testWidgets('menu opens organization and sign-out', (tester) async {
    final c = await _app(tester, RecordingRepo());
    await tester.tap(find.byTooltip('Меню'));
    await tester.pumpAndSettle();
    expect(find.text('Организация'), findsWidgets);
    await tester.tap(find.text('Выйти'));
    await tester.pumpAndSettle();
    expect(c.read(sessionProvider).isAuthenticated, isFalse);
    expect(find.text('Вход'), findsOneWidget);
  });

  testWidgets('200% text on 320 dp with batches: no overflow', (tester) async {
    final repo = RecordingRepo()
      ..items = [
        fakeItem('a',
            name:
                'Очень длинное название партии хлопковых обрезков для переработки'),
        fakeItem('b', status: MaterialStatus.partiallyAllocated),
      ]
      ..total = 2;
    await _app(tester, repo, scale: 2, size: const Size(320, 640));
    expect(tester.takeException(), isNull);
  });

  testWidgets('200% text on 320 dp, empty state: no overflow', (tester) async {
    await _app(tester, RecordingRepo(), scale: 2, size: const Size(320, 640));
    expect(tester.takeException(), isNull);
  });
}
