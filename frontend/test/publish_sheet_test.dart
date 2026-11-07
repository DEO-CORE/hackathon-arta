import 'package:arta/app/theme.dart';
import 'package:arta/core/ui/ui.dart';
import 'package:arta/features/materials/models/material_enums.dart';
import 'package:arta/features/materials/models/material_models.dart';
import 'package:arta/features/materials/presentation/publish_sheet.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

MaterialItem _item({bool complete = true, String name = 'Партия'}) =>
    MaterialItem(
      id: 'm1',
      name: name,
      status: MaterialStatus.draft,
      version: 3,
      availableKg: '120.500',
      materialType: TextileType.cotton,
      condition: MaterialCondition.good,
      city: 'Бишкек',
      isConfirmationCurrent: complete,
      images: complete
          ? const [
              MaterialImage(
                  id: 'i1', mimeType: 'image/jpeg', sizeBytes: 1, sortOrder: 0)
            ]
          : const [],
      balance: const MassBalance(
        totalKg: '120.500',
        availableKg: '120.500',
        heldKg: '0.000',
        transferredKg: '0.000',
        internallyUsedKg: '0.000',
      ),
    );

/// Opens the sheet from a button and records the result.
Future<List<bool>> _open(WidgetTester tester, MaterialItem item,
    {double scale = 1}) async {
  tester.view.physicalSize = const Size(360, 640);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  final results = <bool>[];
  await tester.pumpWidget(MaterialApp(
    theme: buildTheme(),
    builder: (c, w) => MediaQuery(
        data: MediaQuery.of(c).copyWith(textScaler: TextScaler.linear(scale)),
        child: w!),
    home: Builder(
      builder: (c) => Scaffold(
        body: FilledButton(
          onPressed: () async => results.add(await showPublishSheet(c, item)),
          child: const Text('open'),
        ),
      ),
    ),
  ));
  await tester.tap(find.text('open'));
  await tester.pumpAndSettle();
  return results;
}

void main() {
  testWidgets('sheet shows title, key-value rows, status badge and checklist',
      (tester) async {
    await _open(tester, _item());
    expect(find.text('Опубликовать партию?'), findsOneWidget);
    expect(find.byType(AppKeyValueRow), findsNWidgets(5));
    expect(find.text('120,5 кг'), findsOneWidget);
    expect(find.text('Бишкек'), findsOneWidget);
    expect(find.text('Черновик'), findsOneWidget);
    expect(find.text('6 из 6'), findsOneWidget);
  });

  testWidgets('open requirements: shown, publish is disabled, cancel works',
      (tester) async {
    final results = await _open(tester, _item(complete: false));
    expect(find.text('4 из 6'), findsOneWidget);
    expect(find.text('Добавьте хотя бы одно фото'), findsOneWidget);
    final publish = tester.widget<FilledButton>(
        find.widgetWithText(FilledButton, 'Опубликовать'));
    expect(publish.onPressed, isNull);
    await tester.ensureVisible(find.text('Отмена'));
    await tester.tap(find.text('Отмена'));
    await tester.pumpAndSettle();
    expect(results, [false]);
  });

  testWidgets('all done: publish returns true exactly once', (tester) async {
    final results = await _open(tester, _item());
    final btn = find.widgetWithText(FilledButton, 'Опубликовать');
    await tester.ensureVisible(btn);
    await tester.tap(btn);
    // A second tap while the sheet closes must not produce a second result.
    await tester.tap(btn, warnIfMissed: false);
    await tester.pumpAndSettle();
    expect(results, [true]);
  });

  testWidgets('200% text with a long name: no overflow, buttons reachable',
      (tester) async {
    final results = await _open(
        tester,
        _item(
            name: 'Очень длинное название партии трикотажных обрезков хлопка'),
        scale: 2);
    expect(tester.takeException(), isNull);
    final btn = find.widgetWithText(FilledButton, 'Опубликовать');
    await tester.ensureVisible(btn);
    await tester.tap(btn);
    await tester.pumpAndSettle();
    expect(results, [true]);
  });

  testWidgets('dismissing by the close tile cancels', (tester) async {
    final results = await _open(tester, _item());
    await tester.tap(find.byTooltip('Закрыть'));
    await tester.pumpAndSettle();
    expect(results, [false]);
  });
}
