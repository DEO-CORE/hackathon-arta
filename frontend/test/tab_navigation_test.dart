import 'package:arta/app/app.dart';
import 'package:arta/core/ui/ui.dart';
import 'package:arta/features/materials/models/material_enums.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/material_fakes.dart';

Future<void> _app(WidgetTester tester, RecordingRepo repo,
    {Size size = const Size(360, 700), double scale = 1}) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  tester.platformDispatcher.textScaleFactorTestValue = scale;
  addTearDown(tester.view.reset);
  addTearDown(tester.platformDispatcher.clearAllTestValues);
  await tester.pumpWidget(UncontrolledProviderScope(
      container: makeContainer(repo), child: const ArtaApp()));
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('phone: floating nav with three labelled tabs on every tab',
      (tester) async {
    await _app(tester, RecordingRepo());
    expect(find.byType(AppFloatingNav), findsOneWidget);
    expect(find.byType(AppNavRail), findsNothing);
    await tester.tap(find.text('Организация').last);
    await tester.pumpAndSettle();
    expect(find.byType(AppFloatingNav), findsOneWidget);
    expect(find.text('Главная'), findsOneWidget);
  });

  testWidgets('laptop: rail instead of the pill', (tester) async {
    await _app(tester, RecordingRepo(), size: const Size(1200, 800));
    expect(find.byType(AppNavRail), findsOneWidget);
    expect(find.byType(AppFloatingNav), findsNothing);
  });

  testWidgets('catalog keeps a back arrow after switching tabs with the nav',
      (tester) async {
    await _app(tester, RecordingRepo());
    await tester.tap(find.text('Партии').last); // nav tile uses go()
    await tester.pumpAndSettle();
    expect(find.text('Мои партии'), findsOneWidget);
    expect(find.byTooltip('Назад'), findsOneWidget);
    await tester.tap(find.byTooltip('Назад'));
    await tester.pumpAndSettle();
    expect(find.text('Здравствуйте,'), findsOneWidget);
  });

  testWidgets('home shows no invented metrics', (tester) async {
    await _app(tester, RecordingRepo());
    expect(find.textContaining('0 кг'), findsNothing);
    expect(find.textContaining('KGS'), findsNothing);
  });

  testWidgets(
      'long status chip wraps at 360 dp and 200% text: no overflow, last card clear of the nav',
      (tester) async {
    final repo = RecordingRepo()
      ..items = [
        for (var i = 0; i < 3; i++)
          fakeItem('i$i',
              name: 'Партия $i', status: MaterialStatus.partiallyAllocated)
      ]
      ..total = 3;
    await _app(tester, repo, scale: 2);
    await tester.tap(find.text('Партии').last);
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    expect(find.text('Частично распределено'), findsWidgets);
    final scroll = find.byType(ListView).first;
    for (var i = 0; i < 4; i++) {
      await tester.fling(scroll, const Offset(0, -2000), 3000);
      await tester.pumpAndSettle();
    }
    final lastCard = tester.getRect(find.byType(AppPhotoCard).last);
    final nav = tester.getRect(find.byType(AppFloatingNav));
    expect(lastCard.bottom, lessThanOrEqualTo(nav.top));
  });
}
