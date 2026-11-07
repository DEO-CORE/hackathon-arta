import 'dart:io';

import 'package:arta/core/config/app_config.dart';
import 'package:arta/core/network/api_exception.dart';
import 'package:arta/core/session/session.dart';
import 'package:arta/demo/demo_material_repository.dart';
import 'package:arta/features/auth/models/auth_models.dart';
import 'package:arta/demo/demo_reset_section.dart';
import 'package:arta/demo/demo_store.dart';
import 'package:arta/features/materials/models/material_enums.dart';
import 'package:arta/features/materials/models/material_input.dart';
import 'package:arta/features/materials/models/material_rules.dart';
import 'package:arta/features/materials/presentation/material_create_screen.dart';
import 'package:arta/features/materials/presentation/material_detail_screen.dart';
import 'package:arta/features/materials/providers/material_providers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import 'support/material_fakes.dart';

const _create = MaterialCreate(
  name: 'Тестовая партия',
  materialType: TextileType.cotton,
  condition: MaterialCondition.good,
  city: 'Бишкек',
  totalKg: '12.500',
);

PickedPhoto _photo() => PickedPhoto(name: 'IMG_001.jpg', bytes: jpegBytes());

void main() {
  group('demo repository (file store)', () {
    late Directory root;
    setUp(() async {
      root = await Directory.systemTemp.createTemp('arta_demo_test');
    });
    tearDown(() async {
      if (await root.exists()) await root.delete(recursive: true);
    });

    DemoMaterialRepository open() => DemoMaterialRepository(
        store: FileDemoStore(() async => Directory('${root.path}/demo_data')));

    test('create -> photo -> confirm -> publish -> visible as available',
        () async {
      final repo = open();
      var m = await repo.create(_create);
      expect(m.status, MaterialStatus.draft);

      // Publish is refused until photo and confirmation exist (api.md 19.2).
      await expectLater(
        repo.publish(m.id, version: m.version),
        throwsA(isA<ApiException>()
            .having((e) => e.statusCode, 'status', 422)
            .having((e) => e.details?['missing'], 'missing',
                ['images', 'confirmation'])),
      );

      final up = await repo.uploadImage(m.id, _photo());
      m = await repo.get(m.id);
      expect(up.materialVersion, m.version);
      expect(m.images, hasLength(1));

      m = await repo.confirm(m.id, version: m.version);
      expect(m.isConfirmationCurrent, isTrue);
      expect(m.confirmedAt, isNotNull);
      final versionBefore = m.version;

      m = await repo.publish(m.id, version: m.version);
      expect(m.status, MaterialStatus.available);
      expect(m.version, versionBefore);

      final page = await repo.list(status: MaterialStatus.available);
      expect(page.items.map((e) => e.id), contains(m.id));
    });

    test('photo is copied under a random name inside the demo folder',
        () async {
      final repo = open();
      final m = await repo.create(_create);
      final up = await repo.uploadImage(m.id, _photo());
      final url = await repo.imageUrl(m.id, up.image.id);
      final path = Uri.parse(url.url).toFilePath();
      expect(path, startsWith('${root.path}/demo_data/demo_photos/demo_'));
      expect(path, isNot(contains('IMG_001')));
      expect(File(path).readAsBytesSync(), jpegBytes());
    });

    test('state survives a restart (new repository, same folder)', () async {
      final first = open();
      var m = await first.create(_create);
      await first.uploadImage(m.id, _photo());
      m = await first.get(m.id);
      m = await first.confirm(m.id, version: m.version);
      m = await first.publish(m.id, version: m.version);

      final second = open();
      final reread = await second.get(m.id);
      expect(reread.status, MaterialStatus.available);
      expect(reread.images, hasLength(1));
      expect(reread.isConfirmationCurrent, isTrue);
      expect(reread.confirmedAt, isNotNull);
      expect((await second.imageUrl(m.id, reread.images.first.id)).url,
          startsWith('file:'));
      expect(File('${root.path}/demo_data/demo_materials.json').existsSync(),
          isTrue);
    });

    test('editing drops the confirmation and returns the batch to draft',
        () async {
      final repo = open();
      var m = await repo.create(_create);
      await repo.uploadImage(m.id, _photo());
      m = await repo.get(m.id);
      m = await repo.confirm(m.id, version: m.version);
      m = await repo.publish(m.id, version: m.version);

      m = await repo.patch(
          m.id, MaterialPatch(version: m.version, fields: {'city': 'Ош'}));
      expect(m.status, MaterialStatus.draft);
      expect(m.isConfirmationCurrent, isFalse);
      expect(m.confirmedAt, isNull);
    });

    test('stale version gets 409 and archive hides the batch', () async {
      final repo = open();
      final m = await repo.create(_create);
      await expectLater(
        repo.patch(
            m.id, const MaterialPatch(version: 99, fields: {'city': 'Ош'})),
        throwsA(isA<ApiException>()
            .having((e) => e.code, 'code', 'VERSION_CONFLICT')
            .having((e) => e.details?['current_version'], 'v', 1)),
      );
      final archived = await repo.archive(m.id, version: m.version);
      expect(archived.status, MaterialStatus.archived);
      await expectLater(
        repo.confirm(m.id, version: archived.version),
        throwsA(isA<ApiException>()
            .having((e) => e.code, 'code', 'INVALID_TRANSITION')),
      );
    });

    test('reset deletes files and restores the seed', () async {
      final repo = open();
      final m = await repo.create(_create);
      await repo.uploadImage(m.id, _photo());
      await repo.resetDemoData();
      expect(Directory('${root.path}/demo_data/demo_photos').existsSync(),
          isFalse);
      final page = await repo.list();
      expect(page.total, 3);
      expect(page.items.any((e) => e.id == m.id), isFalse);
      // The seed itself is persisted again.
      expect((await open().list()).total, 3);
    });

    test('a corrupt state file falls back to the seed', () async {
      final dir = Directory('${root.path}/demo_data')..createSync();
      File('${dir.path}/demo_materials.json').writeAsStringSync('{not json');
      expect((await open().list()).total, 3);
    });
  });

  group('demo UI', () {
    ProviderContainer demoContainer(DemoMaterialRepository repo,
        {PhotoPicker? picker}) {
      final demo = ProviderContainer(overrides: [
        appConfigProvider.overrideWithValue(
            const AppConfig(apiBaseUrl: '', useDemoData: true)),
        materialRepositoryProvider.overrideWithValue(repo),
        photoPickerProvider.overrideWithValue(picker ?? StubPicker([_photo()])),
      ]);
      addTearDown(demo.dispose);
      demo.read(sessionProvider.notifier).signIn(const LoginResult(
            accessToken: 't',
            user: AuthUser(
                id: 'u',
                email: 'e@x.test',
                role: UserRole.enterprise,
                organizationId: 'o',
                active: true),
          ));
      return demo;
    }

    testWidgets('picked photo is stored by the demo repository on save',
        (tester) async {
      final repo = DemoMaterialRepository();
      final c = demoContainer(repo);
      await pumpScreen(tester, c, const MaterialCreateScreen());
      expect(find.text('Демо: фото сохраняется только на этом устройстве.'),
          findsOneWidget);
      await fillCreateForm(tester);
      await tester.tap(find.text('Добавить фото'));
      await tester.pumpAndSettle();
      expect(find.text('IMG_001.jpg'), findsOneWidget);
      await tester.tap(find.text('Сохранить черновик'));
      await tester.pumpAndSettle();
      final created = (await repo.list()).items.first;
      expect(created.name, 'Хлопковые обрезки');
      expect(created.images, hasLength(1));
    });

    testWidgets('card: confirm in demo, then publish, status becomes Доступно',
        (tester) async {
      final repo = DemoMaterialRepository();
      var m = await repo.create(_create);
      await repo.uploadImage(m.id, _photo());
      m = await repo.get(m.id);
      final c = demoContainer(repo);
      await pumpScreen(tester, c, MaterialDetailScreen(materialId: m.id));
      expect(find.text('Опубликовать'), findsNothing);

      await tester.tap(find.text('Подтвердить характеристики'));
      await tester.pumpAndSettle();
      expect(
          find.textContaining('Демо: подтверждение недоступно'), findsNothing);
      expect(find.textContaining('Подтверждено человеком'), findsOneWidget);

      await tester.tap(find.text('Опубликовать'));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(FilledButton, 'Опубликовать').last);
      await tester.pumpAndSettle();
      expect(find.text('Доступно'), findsWidgets);
      expect((await repo.get(m.id)).status, MaterialStatus.available);
    });

    testWidgets('reset button exists only in demo and restores the seed',
        (tester) async {
      Future<void> pump(ProviderContainer c) async {
        final router = GoRouter(routes: [
          GoRoute(
              path: '/',
              builder: (_, __) =>
                  const Scaffold(body: Center(child: DemoResetSection()))),
          GoRoute(
              path: '/materials',
              builder: (_, __) => const Scaffold(body: Text('catalog'))),
        ]);
        addTearDown(router.dispose);
        await tester.pumpWidget(UncontrolledProviderScope(
            container: c, child: MaterialApp.router(routerConfig: router)));
        await tester.pumpAndSettle();
      }

      // Non-demo: nothing rendered.
      await pump(makeContainer(RecordingRepo()));
      expect(find.text('Сбросить демо-данные'), findsNothing);

      final repo = DemoMaterialRepository();
      await repo.create(_create);
      await pump(demoContainer(repo));
      await tester.tap(find.text('Сбросить демо-данные'));
      await tester.pumpAndSettle();
      expect(find.text('Сбросить демо-данные?'), findsOneWidget);
      await tester.tap(find.text('Отмена'));
      await tester.pumpAndSettle();
      expect((await repo.list()).total, 4); // cancel changes nothing

      await tester.tap(find.text('Сбросить демо-данные'));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(FilledButton, 'Сбросить'));
      await tester.pumpAndSettle();
      expect((await repo.list()).total, 3);
      expect(find.text('catalog'), findsOneWidget);
    });
  });

  test('MemoryDemoStore round trip', () async {
    final s = MemoryDemoStore();
    expect(await s.readState(), isNull);
    await s.writeState('{"a":1}');
    expect(decodeState(await s.readState()), {'a': 1});
    await s.clear();
    expect(await s.readState(), isNull);
  });
}
