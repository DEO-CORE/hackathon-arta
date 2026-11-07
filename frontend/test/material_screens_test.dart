import 'package:arta/features/auth/providers/org_context_provider.dart';
import 'dart:async';
import 'dart:typed_data';

import 'package:arta/core/network/api_exception.dart';
import 'package:arta/core/session/session.dart';
import 'package:arta/features/auth/models/auth_models.dart';
import 'package:arta/features/materials/data/material_repository.dart';
import 'package:arta/features/materials/models/catalog_filter.dart';
import 'package:arta/features/materials/models/material_enums.dart';
import 'package:arta/features/materials/models/material_input.dart';
import 'package:arta/features/materials/models/material_models.dart';
import 'package:arta/features/materials/models/material_rules.dart';
import 'package:arta/features/materials/presentation/catalog_screen.dart';
import 'package:arta/features/materials/presentation/material_create_screen.dart';
import 'package:arta/features/materials/presentation/material_edit_screen.dart';
import 'package:arta/features/materials/providers/material_providers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'support/material_fakes.dart';

MaterialItem item(String id, {int version = 1, String name = 'Демо-партия'}) =>
    MaterialItem(
      id: id,
      name: name,
      status: MaterialStatus.draft,
      version: version,
      availableKg: '10.000',
      materialType: TextileType.cotton,
      condition: MaterialCondition.good,
      city: 'Бишкек',
      images: const [],
      balance: const MassBalance(
        totalKg: '10.000',
        availableKg: '10.000',
        heldKg: '0.000',
        transferredKg: '0.000',
        internallyUsedKg: '0.000',
      ),
    );

class FakeRepo implements MaterialRepository {
  List<MaterialItem> items = [];
  int total = 0;
  ApiException? listError;
  int listCalls = 0;
  int createCalls = 0;
  int uploadCalls = 0;
  bool failUpload = true;
  Completer<MaterialItem>? createGate;
  ApiException? patchError;
  MaterialItem serverItem = item('m1', version: 5);

  @override
  Future<MaterialListPage> list(
      {MaterialStatus? status,
      int page = 1,
      int pageSize = 20,
      CatalogFilter filter = const CatalogFilter()}) async {
    listCalls++;
    if (listError != null) throw listError!;
    final start = (page - 1) * pageSize;
    final slice = items.skip(start).take(pageSize).toList();
    return MaterialListPage(
        items: slice, page: page, pageSize: pageSize, total: total);
  }

  @override
  Future<MaterialItem> get(String id) async => serverItem;

  @override
  Future<MaterialItem> create(MaterialCreate input) {
    createCalls++;
    return createGate?.future ?? Future.value(item('new'));
  }

  @override
  Future<MaterialItem> patch(String id, MaterialPatch patch) async {
    if (patchError != null) throw patchError!;
    return item(id, version: patch.version + 1);
  }

  @override
  Future<ImageUploadResult> uploadImage(String id, PickedPhoto photo) async {
    uploadCalls++;
    if (failUpload) {
      throw const ApiException(
          code: 'UNSUPPORTED_IMAGE',
          message: 'Файл не подходит',
          statusCode: 422);
    }
    return const ImageUploadResult(
      image: MaterialImage(
          id: 'i', mimeType: 'image/jpeg', sizeBytes: 1, sortOrder: 0),
      materialVersion: 2,
    );
  }

  @override
  Future<SignedUrl> imageUrl(String materialId, String imageId) async =>
      throw const ApiException(code: 'NOT_FOUND', message: 'нет');

  @override
  Future<MaterialItem> confirm(String id, {required int version}) async =>
      item(id);

  @override
  Future<MaterialItem> publish(String id, {required int version}) =>
      Future.error(UnimplementedError());

  @override
  Future<MaterialItem> archive(String id, {required int version}) =>
      Future.error(UnimplementedError());
}

class FakePicker implements PhotoPicker {
  @override
  Future<List<PickedPhoto>> pick() async => [
        PickedPhoto(
            name: 'a.jpg',
            bytes: Uint8List.fromList([0xFF, 0xD8, 0xFF, 0xE0, 0, 0])),
      ];
}

Future<void> pump(WidgetTester tester, FakeRepo repo, Widget home,
    {UserRole role = UserRole.enterprise, Size? size}) async {
  if (size != null) {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
  }
  final container = ProviderContainer(overrides: [
    orgContextSourceProvider.overrideWithValue(FixtureOrgContextSource()),
    materialRepositoryProvider.overrideWithValue(repo),
    photoPickerProvider.overrideWithValue(FakePicker()),
  ]);
  addTearDown(container.dispose);
  container.read(sessionProvider.notifier).signIn(LoginResult(
        accessToken: 't',
        user: AuthUser(
            id: 'u',
            email: 'e@x.test',
            role: role,
            organizationId: 'o',
            active: true),
      ));
  await tester.pumpWidget(UncontrolledProviderScope(
    container: container,
    child: MaterialApp(home: home),
  ));
  await tester.pump();
  await tester.pump();
}

void main() {
  group('catalog', () {
    testWidgets('empty state for owner', (tester) async {
      await pump(tester, FakeRepo(), const CatalogScreen());
      expect(find.text('Партий пока нет. Добавьте первую.'), findsOneWidget);
    });

    testWidgets('error then retry shows list', (tester) async {
      final repo = FakeRepo()..listError = ApiException.network();
      await pump(tester, repo, const CatalogScreen());
      expect(find.text('Повторить'), findsOneWidget);
      repo
        ..listError = null
        ..items = [item('a')]
        ..total = 1;
      await tester.tap(find.text('Повторить'));
      await tester.pump();
      await tester.pump();
      expect(find.text('Демо-партия'), findsOneWidget);
      expect(find.text('Черновик'), findsWidgets);
    });

    testWidgets('load more appends the next page', (tester) async {
      final repo = FakeRepo()
        ..items = [for (var i = 0; i < 25; i++) item('$i', name: 'Партия $i')]
        ..total = 25;
      await pump(tester, repo, const CatalogScreen(),
          size: const Size(400, 30000));
      expect(find.text('Партия 19'), findsOneWidget);
      expect(find.text('Партия 20'), findsNothing);
      await tester.ensureVisible(find.text('Показать ещё'));
      await tester.tap(find.text('Показать ещё'));
      await tester.pump();
      await tester.pump();
      expect(find.text('Партия 24'), findsOneWidget);
      expect(find.text('Показать ещё'), findsNothing);
    });
  });

  group('create', () {
    testWidgets('empty submit shows validation and no request', (tester) async {
      final repo = FakeRepo();
      await pump(tester, repo, const MaterialCreateScreen(),
          size: const Size(400, 1600));
      await tester.tap(find.text('Сохранить черновик'));
      await tester.pump();
      expect(find.text('Укажите название партии.'), findsOneWidget);
      expect(find.text('Укажите массу в кг.'), findsOneWidget);
      expect(repo.createCalls, 0);
    });

    testWidgets('second tap while in flight does not send twice',
        (tester) async {
      final repo = FakeRepo()..createGate = Completer();
      await pump(tester, repo, const MaterialCreateScreen(),
          size: const Size(400, 1600));
      await _fill(tester);
      await tester.tap(find.text('Сохранить черновик'));
      await tester.pump();
      expect(find.text('Сохранение…'), findsOneWidget);
      await tester.tap(find.text('Сохранение…'), warnIfMissed: false);
      await tester.pump();
      expect(repo.createCalls, 1);
    });

    testWidgets('photo failure keeps data and retry does not recreate',
        (tester) async {
      final repo = FakeRepo();
      await pump(tester, repo, const MaterialCreateScreen(),
          size: const Size(400, 1600));
      await _fill(tester);
      await tester.tap(find.text('Добавить фото'));
      await tester.pump();
      await tester.tap(find.text('Сохранить черновик'));
      await tester.pump();
      await tester.pump();
      expect(repo.createCalls, 1);
      expect(find.textContaining('Файл не подходит'), findsOneWidget);
      expect(find.text('Повторить загрузку фото'), findsOneWidget);
      expect(find.widgetWithText(TextFormField, 'Хлопковые обрезки'),
          findsOneWidget);
      await tester.tap(find.text('Повторить загрузку фото'));
      await tester.pump();
      await tester.pump();
      expect(repo.createCalls, 1);
      expect(repo.uploadCalls, 2);
    });
  });

  group('edit', () {
    testWidgets('409 shows server version and refresh action', (tester) async {
      final repo = FakeRepo()
        ..patchError = const ApiException(
          code: 'VERSION_CONFLICT',
          message: 'x',
          statusCode: 409,
          details: {'current_version': 7},
        );
      await pump(tester, repo, const MaterialEditScreen(materialId: 'm1'),
          size: const Size(400, 1600));
      await tester.enterText(
          find.widgetWithText(TextFormField, 'Демо-партия'), 'Новое имя');
      await tester.tap(find.text('Сохранить'));
      await tester.pump();
      await tester.pump();
      expect(find.textContaining('версия на сервере: 7'), findsOneWidget);
      expect(find.text('Обновить данные'), findsOneWidget);
      // typed value survives
      expect(find.widgetWithText(TextFormField, 'Новое имя'), findsOneWidget);
    });

    testWidgets('ACTIVE_OBLIGATIONS shows readable text', (tester) async {
      final repo = FakeRepo()
        ..patchError = const ApiException(
          code: 'ACTIVE_OBLIGATIONS',
          message: 'x',
          statusCode: 409,
          details: {
            'blocked_fields': ['city']
          },
        );
      await pump(tester, repo, const MaterialEditScreen(materialId: 'm1'),
          size: const Size(400, 1600));
      await tester.enterText(
          find.widgetWithText(TextFormField, 'Бишкек'), 'Ош');
      await tester.tap(find.text('Сохранить'));
      await tester.pump();
      await tester.pump();
      expect(find.textContaining('Нельзя изменить: есть активные заявки.'),
          findsOneWidget);
    });
  });
}

Future<void> _fill(WidgetTester tester) async {
  Finder field(String label) => find.widgetWithText(TextFormField, label);
  await tester.enterText(field('Название (обязательно)'), 'Хлопковые обрезки');
  await tester.enterText(field('Масса'), '12,5');
  await tester.enterText(field('Город'), 'Бишкек');
  await tester.tap(find.text('Тип материала'));
  await tester.pumpAndSettle();
  await tester.tap(find.text('Хлопок').last);
  await tester.pumpAndSettle();
  await tester.tap(find.text('Состояние'));
  await tester.pumpAndSettle();
  await tester.tap(find.text('Хорошее').last);
  await tester.pumpAndSettle();
}
