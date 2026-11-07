import 'package:arta/app/theme.dart';
import 'package:arta/core/ui/ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

const _long =
    'Очень длинное название партии трикотажных обрезков хлопкового полотна для переработки';

Future<void> _pump(
  WidgetTester tester,
  Widget child, {
  double scale = 1,
  Size size = const Size(360, 640),
  Widget? bar,
}) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(MaterialApp(
    theme: buildTheme(),
    builder: (c, w) => MediaQuery(
      data: MediaQuery.of(c).copyWith(textScaler: TextScaler.linear(scale)),
      child: w!,
    ),
    home: Scaffold(
      appBar: bar as PreferredSizeWidget?,
      body: SingleChildScrollView(child: child),
    ),
  ));
}

const _items = [
  AppNavItem(
      label: 'Главная',
      icon: Icons.home_outlined,
      selectedIcon: Icons.home,
      route: '/'),
  AppNavItem(
      label: 'Партии',
      icon: Icons.inventory_2_outlined,
      selectedIcon: Icons.inventory_2,
      route: '/materials'),
  AppNavItem(
      label: 'Организация',
      icon: Icons.business_outlined,
      selectedIcon: Icons.business,
      route: '/organization'),
];

void main() {
  group('AppTopBar', () {
    testWidgets('long title at 200% does not overflow; back has a name',
        (tester) async {
      var back = 0;
      await _pump(tester, const SizedBox(),
          scale: 2, bar: AppTopBar(title: _long, onBack: () => back++));
      expect(tester.takeException(), isNull);
      await tester.tap(find.byTooltip('Назад'));
      expect(back, 1);
    });

    testWidgets('disabled trailing tile cannot be tapped', (tester) async {
      await _pump(tester, const SizedBox(),
          bar: const AppTopBar(
            title: 'Партия',
            showBack: false,
            trailing: AppIconTile(
                icon: Icons.logout, tooltip: 'Выйти', onPressed: null),
          ));
      expect(find.byTooltip('Выйти'), findsOneWidget);
      expect(find.byTooltip('Назад'), findsNothing);
    });
  });

  group('AppFloatingNav and AppShell', () {
    testWidgets(
        'only the active item shows a label; the others keep a semantic label',
        (tester) async {
      var picked = -1;
      await _pump(
        tester,
        AppFloatingNav(
            items: _items, currentIndex: 1, onSelected: (i) => picked = i),
        scale: 2,
      );
      expect(tester.takeException(), isNull);
      expect(find.text('Партии'), findsOneWidget);
      expect(find.text('Главная'), findsNothing);
      expect(find.text('Организация'), findsNothing);
      for (final l in ['Главная', 'Партии', 'Организация']) {
        expect(find.bySemanticsLabel(l), findsOneWidget);
      }
      await tester.tap(find.bySemanticsLabel('Организация'));
      expect(picked, 2);
    });

    testWidgets('phone shows the pill, laptop shows the rail', (tester) async {
      Widget shell() => AppShell(
            items: _items,
            currentIndex: 0,
            onSelected: (_) {},
            child: const SizedBox.expand(),
          );
      tester.view.physicalSize = const Size(360, 640);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(MaterialApp(home: Scaffold(body: shell())));
      expect(find.byType(AppFloatingNav), findsOneWidget);
      expect(find.byType(AppNavRail), findsNothing);
      tester.view.physicalSize = const Size(1200, 800);
      await tester.pump();
      expect(find.byType(AppNavRail), findsOneWidget);
      expect(find.byType(AppFloatingNav), findsNothing);
    });

    testWidgets('content gets bottom padding for the pill', (tester) async {
      tester.view.physicalSize = const Size(360, 640);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      late EdgeInsets padding;
      await tester.pumpWidget(MaterialApp(
        home: AppShell(
          items: _items,
          currentIndex: 0,
          onSelected: (_) {},
          child: Builder(builder: (c) {
            padding = MediaQuery.paddingOf(c);
            return const SizedBox.expand();
          }),
        ),
      ));
      expect(padding.bottom, greaterThanOrEqualTo(AppFloatingNav.height));
    });
  });

  group('AppStatTriplet', () {
    testWidgets('shows Зарезервировано, never Удержано', (tester) async {
      await _pump(
          tester,
          const AppStatTriplet(
              freeKg: '45',
              reservedKg: '5',
              transferredKg: '0',
              totalKg: '50'));
      expect(find.text('Зарезервировано'), findsOneWidget);
      expect(find.text('Удержано'), findsNothing);
      expect(find.text('Всего 50 кг'), findsOneWidget);
    });

    testWidgets('200% scale and narrow width do not overflow', (tester) async {
      await _pump(
          tester,
          const AppStatTriplet(
              freeKg: '1 250,5', reservedKg: '320', transferredKg: '99'),
          scale: 2,
          size: const Size(320, 640));
      expect(tester.takeException(), isNull);
    });
  });

  group('AppProgressChecklist', () {
    testWidgets('count chip, action only on open rows, long text',
        (tester) async {
      var tapped = 0;
      await _pump(
        tester,
        AppProgressChecklist(title: 'Что осталось до публикации', items: [
          const AppChecklistItem(title: 'Тип материала указан', done: true),
          AppChecklistItem(
              title: _long,
              subtitle: _long,
              done: false,
              actionLabel: 'Изменить',
              onAction: () => tapped++),
        ]),
        scale: 2,
      );
      expect(tester.takeException(), isNull);
      expect(find.text('1 из 2'), findsOneWidget);
      expect(find.text('Изменить'), findsOneWidget);
      await tester.tap(find.text('Изменить'));
      expect(tapped, 1);
    });
  });

  group('AppBottomSheet and AppSuccessView', () {
    testWidgets('sheet shows title and closes by the close tile',
        (tester) async {
      await tester.pumpWidget(MaterialApp(
        home: Builder(
          builder: (c) => Scaffold(
            body: TextButton(
              onPressed: () => AppBottomSheet.show<void>(c,
                  title: 'Опубликовать партию?',
                  builder: (_) => const Text('Тело')),
              child: const Text('open'),
            ),
          ),
        ),
      ));
      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();
      expect(find.text('Опубликовать партию?'), findsOneWidget);
      await tester.tap(find.byTooltip('Закрыть'));
      await tester.pumpAndSettle();
      expect(find.text('Тело'), findsNothing);
    });

    testWidgets('success view at 200% with long text and both actions',
        (tester) async {
      var a = 0, b = 0;
      tester.view.physicalSize = const Size(360, 640);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(MaterialApp(
        builder: (c, w) => MediaQuery(
            data: MediaQuery.of(c)
                .copyWith(textScaler: const TextScaler.linear(2)),
            child: w!),
        home: Scaffold(
          body: AppSuccessView(
            title: 'Партия опубликована',
            message: _long,
            summary: const [('Название', _long), ('Свободно', '45 кг')],
            primaryLabel: 'Открыть партию',
            onPrimary: () => a++,
            secondaryLabel: 'В каталог',
            onSecondary: () => b++,
          ),
        ),
      ));
      expect(tester.takeException(), isNull);
      await tester.ensureVisible(find.text('Открыть партию'));
      await tester.tap(find.text('Открыть партию'));
      await tester.ensureVisible(find.text('В каталог'));
      await tester.tap(find.text('В каталог'));
      expect((a, b), (1, 1));
    });
  });

  group('AppPhotoUpload', () {
    testWidgets('states, counter, accessible controls', (tester) async {
      var removed = -1, retried = -1, added = 0;
      await _pump(
        tester,
        AppPhotoUpload(
          photos: const [
            AppPhotoTileData(name: 'a.jpg', status: AppPhotoStatus.uploading),
            AppPhotoTileData(name: 'b.jpg', status: AppPhotoStatus.failed),
            AppPhotoTileData(name: _long, status: AppPhotoStatus.done),
          ],
          onAdd: () => added++,
          onRemove: (i) => removed = i,
          onRetry: (i) => retried = i,
        ),
        scale: 2,
      );
      expect(tester.takeException(), isNull);
      expect(find.text('3 из 5'), findsOneWidget);
      await tester.tap(find.byTooltip('Убрать фото 3 из списка'));
      await tester.tap(find.byTooltip('Повторить загрузку фото 2'));
      expect((removed, retried), (2, 1));
      expect(find.byType(CircularProgressIndicator), findsOneWidget);
      await tester.tap(find.bySemanticsLabel('Добавить фото'));
      expect(added, 1);
    });

    testWidgets('disabled and at the limit: add does nothing', (tester) async {
      var added = 0;
      await _pump(
        tester,
        AppPhotoUpload(
          photos: [
            for (var i = 0; i < 5; i++)
              const AppPhotoTileData(name: 'x', status: AppPhotoStatus.done),
          ],
          onAdd: () => added++,
        ),
      );
      await tester.tap(find.bySemanticsLabel('Добавить фото'),
          warnIfMissed: false);
      expect(added, 0);
      expect(find.text('5 из 5'), findsOneWidget);
    });
  });

  group('AppPhotoCard', () {
    testWidgets('long Russian text at 200%, one tap target', (tester) async {
      var tapped = 0;
      await _pump(
        tester,
        AppPhotoCard(
          photo: const ColoredBox(color: Colors.grey),
          title: _long,
          meta: '$_long · Бишкек',
          highlight: 'Свободно: 45 кг',
          badge: const AppStatusBadge(
              label: 'Доступно', icon: Icons.storefront, tone: AppTone.success),
          onTap: () => tapped++,
        ),
        scale: 2,
      );
      expect(tester.takeException(), isNull);
      await tester.tap(find.text('Свободно: 45 кг'));
      expect(tapped, 1);
    });
  });

  group('AiSuggestionCard', () {
    testWidgets('suggested and confirmed are separate and labelled in text',
        (tester) async {
      await _pump(
        tester,
        const Column(children: [
          AiSuggestionCard(title: 'Визуальные признаки', items: [
            AiSuggestionItem(
                label: 'Цвет',
                value: 'Синий',
                suitability: 'средняя',
                reason: _long),
          ]),
          AiConfirmedBlock(
              entries: [AiConfirmedEntry(label: 'Цвет', value: 'Синий')],
              authorDate: 'Иван, 07.11.2026'),
        ]),
        scale: 2,
      );
      expect(tester.takeException(), isNull);
      expect(find.text('Предложено ИИ'), findsOneWidget);
      expect(find.text('Подтверждено вами'), findsOneWidget);
      expect(find.text(aiLimitsNotice), findsOneWidget);
      expect(find.text('Пригодность: средняя'), findsOneWidget);
    });
  });

  group('AppKeyValueRow and AppLinkCard', () {
    testWidgets('long value wraps; link card taps', (tester) async {
      var tapped = 0;
      await _pump(
        tester,
        Column(children: [
          const AppKeyValueRow(label: 'Состав', value: _long),
          AppLinkCard(
              icon: Icons.business,
              title: 'Организация',
              subtitle: _long,
              onTap: () => tapped++),
        ]),
        scale: 2,
      );
      expect(tester.takeException(), isNull);
      await tester.ensureVisible(find.text('Организация'));
      await tester.tap(find.text('Организация'));
      expect(tapped, 1);
    });
  });

  group('AppButton disabled and loading', () {
    testWidgets('loading blocks a second tap and shows the loading label',
        (tester) async {
      var taps = 0;
      await _pump(
          tester,
          AppButton(
              label: 'Войти',
              loadingLabel: 'Отправка…',
              loading: true,
              onPressed: () => taps++));
      await tester.tap(find.text('Отправка…'));
      expect(taps, 0);
    });

    testWidgets('disabled button ignores taps', (tester) async {
      var taps = 0;
      await _pump(tester, const AppButton(label: 'Сохранить', onPressed: null));
      await tester.tap(find.text('Сохранить'));
      expect(taps, 0);
    });
  });
}
