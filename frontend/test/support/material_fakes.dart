import 'dart:async';
import 'dart:typed_data';

import 'package:arta/core/network/api_exception.dart';
import 'package:arta/core/session/session.dart';
import 'package:arta/features/auth/models/auth_models.dart';
import 'package:arta/features/materials/data/material_repository.dart';
import 'package:arta/features/materials/models/material_enums.dart';
import 'package:arta/features/materials/models/material_input.dart';
import 'package:arta/features/materials/models/material_models.dart';
import 'package:arta/features/materials/models/material_rules.dart';
import 'package:arta/features/materials/providers/material_providers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

MaterialItem fakeItem(
  String id, {
  int version = 1,
  String name = 'Демо-партия',
  MaterialStatus status = MaterialStatus.draft,
}) =>
    MaterialItem(
      id: id,
      name: name,
      status: status,
      version: version,
      availableKg: '10.000',
      materialType: TextileType.cotton,
      condition: MaterialCondition.good,
      city: 'Бишкек',
      pricePerKg: '45.00',
      images: const [],
      balance: const MassBalance(
        totalKg: '10.000',
        availableKg: '10.000',
        heldKg: '0.000',
        transferredKg: '0.000',
        internallyUsedKg: '0.000',
      ),
    );

/// Recording fake: every call is counted so tests can assert on side effects.
class RecordingRepo implements MaterialRepository {
  List<MaterialItem> items = [];
  int total = 0;
  ApiException? listError;
  ApiException? createError;
  ApiException? patchError;
  Object? uploadError;
  Completer<MaterialItem>? createGate;
  Completer<MaterialListPage>? listGate;
  Completer<void>? patchGate;
  MaterialItem serverItem = fakeItem('m1', version: 5);

  int listCalls = 0;
  int getCalls = 0;
  int createCalls = 0;
  int uploadCalls = 0;
  int patchCalls = 0;
  MaterialStatus? lastStatus;
  final statusHistory = <MaterialStatus?>[];
  MaterialCreate? lastCreate;
  MaterialPatch? lastPatch;

  int get totalCalls =>
      listCalls + getCalls + createCalls + uploadCalls + patchCalls;

  @override
  Future<MaterialListPage> list(
      {MaterialStatus? status, int page = 1, int pageSize = 20}) async {
    listCalls++;
    lastStatus = status;
    statusHistory.add(status);
    if (listGate != null) return listGate!.future;
    if (listError != null) throw listError!;
    final start = (page - 1) * pageSize;
    final src = status == null
        ? items
        : items.where((e) => e.status == status).toList();
    return MaterialListPage(
      items: src.skip(start).take(pageSize).toList(),
      page: page,
      pageSize: pageSize,
      total: status == null ? total : src.length,
    );
  }

  @override
  Future<MaterialItem> get(String id) async {
    getCalls++;
    return serverItem;
  }

  @override
  Future<MaterialItem> create(MaterialCreate input) {
    createCalls++;
    lastCreate = input;
    if (createError != null) return Future.error(createError!);
    return createGate?.future ?? Future.value(fakeItem('new'));
  }

  @override
  Future<MaterialItem> patch(String id, MaterialPatch patch) async {
    patchCalls++;
    lastPatch = patch;
    if (patchGate != null) await patchGate!.future;
    if (patchError != null) throw patchError!;
    return fakeItem(id, version: patch.version + 1);
  }

  @override
  Future<ImageUploadResult> uploadImage(String id, PickedPhoto photo) async {
    uploadCalls++;
    final err = uploadError;
    if (err != null) throw err;
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
      fakeItem(id);

  @override
  Future<MaterialItem> publish(String id, {required int version}) =>
      Future.error(UnimplementedError());

  @override
  Future<MaterialItem> archive(String id, {required int version}) =>
      Future.error(UnimplementedError());
}

Uint8List jpegBytes([int extra = 0]) => Uint8List.fromList(
    [0xFF, 0xD8, 0xFF, 0xE0, 0, 0, ...List.filled(extra, 0)]);

class StubPicker implements PhotoPicker {
  StubPicker(this.photos);
  List<PickedPhoto> photos;
  @override
  Future<List<PickedPhoto>> pick() async => photos;
}

ProviderContainer makeContainer(RecordingRepo repo,
    {PhotoPicker? picker, UserRole role = UserRole.enterprise}) {
  final container = ProviderContainer(overrides: [
    materialRepositoryProvider.overrideWithValue(repo),
    photoPickerProvider.overrideWithValue(
        picker ?? StubPicker([PickedPhoto(name: 'a.jpg', bytes: jpegBytes())])),
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
  return container;
}

/// Hosts [home] inside a GoRouter, on top of a blank root, so screens that
/// call pop/pushReplacement work and navigation targets are observable.
Future<void> pumpScreen(
    WidgetTester tester, ProviderContainer container, Widget home,
    {Size size = const Size(400, 1600)}) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  final router = GoRouter(routes: [
    GoRoute(path: '/', builder: (_, __) => const Scaffold(body: Text('root'))),
    GoRoute(path: '/under-test', builder: (_, __) => home),
    GoRoute(
        path: '/materials/:id',
        builder: (_, st) =>
            Scaffold(body: Text('detail-stub ${st.pathParameters['id']}'))),
  ]);
  addTearDown(router.dispose);
  await tester.pumpWidget(UncontrolledProviderScope(
    container: container,
    child: MaterialApp.router(routerConfig: router),
  ));
  await tester.pumpAndSettle();
  router.push('/under-test');
  await tester.pumpAndSettle();
}

Future<void> fillCreateForm(WidgetTester tester,
    {String name = 'Хлопковые обрезки',
    String mass = '12,5',
    String city = 'Бишкек'}) async {
  Finder field(String label) => find.widgetWithText(TextFormField, label);
  await tester.enterText(field('Название (обязательно)'), name);
  await tester.enterText(field('Масса'), mass);
  await tester.enterText(field('Город'), city);
  await tester.tap(find.text('Тип материала'));
  await tester.pumpAndSettle();
  await tester.tap(find.text('Хлопок').last);
  await tester.pumpAndSettle();
  await tester.tap(find.text('Состояние'));
  await tester.pumpAndSettle();
  await tester.tap(find.text('Хорошее').last);
  await tester.pumpAndSettle();
}
