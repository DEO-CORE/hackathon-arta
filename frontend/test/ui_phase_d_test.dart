import 'package:flutter/rendering.dart';
import 'package:arta/app/theme.dart';
import 'package:arta/core/ui/ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

Future<void> _pump(WidgetTester tester, Widget child,
    {double scale = 1, Size size = const Size(360, 640)}) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(MaterialApp(
    theme: buildTheme(),
    builder: (c, w) => MediaQuery(
        data: MediaQuery.of(c).copyWith(textScaler: TextScaler.linear(scale)),
        child: w!),
    home: child,
  ));
}

void main() {
  group('AppSuccessScreen', () {
    Widget screen({VoidCallback? a, VoidCallback? b}) => AppSuccessScreen(
          title: 'Партия опубликована',
          message: 'Теперь партию видят покупатели в каталоге.',
          summary: const [
            ('Название', 'Очень длинное название партии трикотажных обрезков'),
            ('Статус', 'Доступно'),
            ('Масса', '120,5 кг'),
          ],
          secondaryLabel: 'К партии',
          onSecondary: a ?? () {},
          primaryLabel: 'К каталогу',
          onPrimary: b ?? () {},
        );

    testWidgets('heading, summary card and the pinned button pair',
        (tester) async {
      var item = 0, catalog = 0;
      await _pump(tester, screen(a: () => item++, b: () => catalog++));
      expect(find.text('Партия опубликована'), findsOneWidget);
      expect(find.text('Статус'), findsOneWidget);
      expect(find.text('120,5 кг'), findsOneWidget);
      // Pinned: both buttons are in the bottom bar, below the summary.
      expect(find.byType(AppBottomBar), findsOneWidget);
      expect(find.widgetWithText(OutlinedButton, 'К партии'), findsOneWidget);
      expect(find.widgetWithText(FilledButton, 'К каталогу'), findsOneWidget);
      await tester.tap(find.text('К партии'));
      await tester.tap(find.text('К каталогу'));
      expect((item, catalog), (1, 1));
    });

    testWidgets('200% text: no overflow, buttons stay reachable',
        (tester) async {
      var catalog = 0;
      await _pump(tester, screen(b: () => catalog++), scale: 2);
      expect(tester.takeException(), isNull);
      await tester.tap(find.text('К каталогу'));
      expect(catalog, 1);
    });
  });

  group('AppMassBar', () {
    const seg = [
      AppMassSegment(
          kind: AppMassKind.free,
          label: 'Свободно',
          valueText: '7 кг',
          weight: 7),
      AppMassSegment(
          kind: AppMassKind.reserved,
          label: 'Зарезервировано',
          valueText: '0 кг',
          weight: 0),
      AppMassSegment(
          kind: AppMassKind.transferred,
          label: 'Передано',
          valueText: '0 кг',
          weight: 0),
      AppMassSegment(
          kind: AppMassKind.internal,
          label: 'Использовано внутри',
          valueText: '0 кг',
          weight: 0),
    ];

    testWidgets('zero segments keep their labels; semantics lists all',
        (tester) async {
      await _pump(
          tester,
          const Padding(
              padding: EdgeInsets.all(16), child: AppMassBar(segments: seg)));
      for (final l in [
        'Свободно',
        'Зарезервировано',
        'Передано',
        'Использовано внутри'
      ]) {
        expect(find.text(l), findsOneWidget);
      }
      expect(find.bySemanticsLabel(RegExp('Свободно: 7 кг')), findsOneWidget);
    });

    testWidgets('long labels at 200% on a narrow phone do not overflow',
        (tester) async {
      await _pump(
          tester,
          const SingleChildScrollView(
              padding: EdgeInsets.all(16), child: AppMassBar(segments: seg)),
          scale: 2,
          size: const Size(320, 640));
      expect(tester.takeException(), isNull);
    });

    testWidgets('7 kg of 7: the free segment is solid and fills the strip',
        (tester) async {
      await _pump(
          tester,
          const Padding(
              padding: EdgeInsets.all(16), child: AppMassBar(segments: seg)));
      // The strip comes first in the tree; the legend swatch is 12 dp wide.
      final solid = find
          .byWidgetPredicate(
              (w) => w is ColoredBox && w.color == AppColors.success)
          .first;
      final r = tester.getRect(solid);
      expect(r.height, 12);
      // 328 dp strip: free takes most of it, stubs are thin.
      expect(r.width, greaterThan(250));
    });

    testWidgets('mix: reserved and transferred get their own sizes',
        (tester) async {
      await _pump(
          tester,
          const Padding(
              padding: EdgeInsets.all(16),
              child: AppMassBar(segments: [
                AppMassSegment(
                    kind: AppMassKind.free,
                    label: 'Свободно',
                    valueText: '5 кг',
                    weight: 5),
                AppMassSegment(
                    kind: AppMassKind.reserved,
                    label: 'Зарезервировано',
                    valueText: '3 кг',
                    weight: 3),
                AppMassSegment(
                    kind: AppMassKind.transferred,
                    label: 'Передано',
                    valueText: '2 кг',
                    weight: 2),
              ])));
      final free = tester.getRect(find
          .byWidgetPredicate(
              (w) => w is ColoredBox && w.color == AppColors.success)
          .first);
      final held = tester.getRect(find
          .byWidgetPredicate(
              (w) => w is ColoredBox && w.color == AppColors.primary)
          .first);
      expect(free.width, greaterThan(held.width));
      expect(held.height, 12);
      expect(find.byType(AppHatch), findsNWidgets(2)); // strip + legend
    });

    testWidgets('0 kg total: empty strip, no coloured segments, labels stay',
        (tester) async {
      await _pump(
          tester,
          const Padding(
              padding: EdgeInsets.all(16),
              child: AppMassBar(segments: [
                AppMassSegment(
                    kind: AppMassKind.free,
                    label: 'Свободно',
                    valueText: '0 кг',
                    weight: 0),
                AppMassSegment(
                    kind: AppMassKind.reserved,
                    label: 'Зарезервировано',
                    valueText: '0 кг',
                    weight: 0),
              ])));
      // Only the 12 dp legend swatch is green; the strip itself is a grey track.
      expect(
          find.byWidgetPredicate(
              (w) => w is ColoredBox && w.color == AppColors.success),
          findsOneWidget);
      expect(
          find.byWidgetPredicate(
              (w) => w is ColoredBox && w.color == AppColors.surfaceSunken),
          findsWidgets);
      expect(find.text('Свободно'), findsOneWidget);
    });

    // Widget tests render with the square Ahem font (every glyph is 1 em
    // wide), so a 15-letter word at 200% is wider than a 320 dp phone there but
    // not in Roboto. The one-line check therefore uses 130%; 200% is checked
    // for overflow only.
    testWidgets('"Зарезервировано" stays on one line at 320 dp and 130%',
        (tester) async {
      await _pump(
          tester,
          const SingleChildScrollView(
              padding: EdgeInsets.all(16), child: AppMassBar(segments: seg)),
          scale: 1.3,
          size: const Size(320, 640));
      final para =
          tester.renderObject<RenderParagraph>(find.text('Зарезервировано'));
      expect(para.size.height, lessThan(24));
      expect(tester.takeException(), isNull);
    });

    testWidgets('all zero: equal stubs, no crash', (tester) async {
      await _pump(
          tester,
          const AppMassBar(segments: [
            AppMassSegment(
                kind: AppMassKind.free,
                label: 'Свободно',
                valueText: '0 кг',
                weight: 0),
            AppMassSegment(
                kind: AppMassKind.reserved,
                label: 'Зарезервировано',
                valueText: '0 кг',
                weight: 0),
          ]));
      expect(tester.takeException(), isNull);
    });
  });
}
