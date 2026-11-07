import 'dart:async';

import 'package:arta/core/network/api_exception.dart';
import 'package:arta/features/materials/models/lifecycle_error.dart';
import 'package:arta/features/materials/models/material_enums.dart';
import 'package:arta/features/materials/models/material_models.dart';
import 'package:arta/features/materials/models/material_rules.dart';
import 'package:arta/features/materials/models/publish_requirements.dart';
import 'package:arta/features/materials/presentation/material_detail_screen.dart';
import 'package:arta/features/materials/providers/material_providers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/material_fakes.dart';

MaterialItem ready({
  String id = 'm1',
  int version = 3,
  MaterialStatus status = MaterialStatus.draft,
  String total = '10.000',
  bool confirmed = true,
  bool withImage = true,
  String held = '0.000',
}) =>
    MaterialItem(
      id: id,
      name: 'Партия',
      status: status,
      version: version,
      availableKg: total,
      materialType: TextileType.cotton,
      condition: MaterialCondition.good,
      city: 'Бишкек',
      isConfirmationCurrent: confirmed,
      images: withImage
          ? const [
              MaterialImage(
                  id: 'i1', mimeType: 'image/jpeg', sizeBytes: 1, sortOrder: 0)
            ]
          : const [],
      balance: MassBalance(
        totalKg: total,
        availableKg: total,
        heldKg: held,
        transferredKg: '0.000',
        internallyUsedKg: '0.000',
      ),
    );

class LifeRepo extends RecordingRepo {
  MaterialItem current = ready();
  ApiException? lifeError;
  Completer<void>? gate;
  int publishCalls = 0;
  int archiveCalls = 0;
  int? lastVersion;

  @override
  Future<MaterialItem> get(String id) async {
    getCalls++;
    return current;
  }

  @override
  Future<MaterialItem> publish(String id, {required int version}) async {
    publishCalls++;
    lastVersion = version;
    if (gate != null) await gate!.future;
    if (lifeError != null) throw lifeError!;
    return current = ready(status: MaterialStatus.available, version: version);
  }

  @override
  Future<MaterialItem> archive(String id, {required int version}) async {
    archiveCalls++;
    lastVersion = version;
    if (gate != null) await gate!.future;
    if (lifeError != null) throw lifeError!;
    return current =
        ready(status: MaterialStatus.archived, version: version + 1);
  }
}

Future<void> openDetail(WidgetTester tester, LifeRepo repo) async {
  final c = makeContainer(repo);
  await pumpScreen(tester, c, const MaterialDetailScreen(materialId: 'm1'));
}

void main() {
  group('publish rules', () {
    test('zero mass is a valid draft value but blocks publishing', () {
      expect(validateDraftMassKg('0'), isNull);
      expect(validateDraftMassKg('0.000'), isNull);
      expect(validateMassKg('0'), isNotNull);
      final m = ready(total: '0.000');
      expect(missingPublishFields(m), ['total_kg']);
      expect(publishMissingLabels(['total_kg']), ['Укажите массу больше нуля']);
    });

    test('missing list covers every requirement with human labels', () {
      final m = ready(confirmed: false, withImage: false);
      expect(missingPublishFields(m), ['images', 'confirmation']);
      expect(publishMissingLabels(['unknown_field']).single,
          isNot(contains('unknown_field')));
    });
  });

  group('error texts', () {
    String t(int status, {String code = 'X', Map<String, dynamic>? d}) =>
        lifecycleErrorText(ApiException(
            code: code, message: 'raw', statusCode: status, details: d));

    test('maps statuses and codes to Russian', () {
      expect(t(403), 'Нет доступа к этой партии');
      expect(t(404), 'Партия не найдена или недоступна');
      expect(t(409, code: 'INVALID_TRANSITION'),
          'Действие недоступно для текущего статуса');
      expect(t(409, code: 'ACTIVE_OBLIGATIONS'), isNot(contains('ACTIVE')));
      expect(t(429, d: {'retry_after_seconds': 7}),
          'Слишком много запросов, попробуйте через 7 сек');
      expect(t(500), contains('Повторите'));
    });
  });

  group('detail screen', () {
    testWidgets('draft with gaps shows checklist and no publish button',
        (tester) async {
      final repo = LifeRepo()
        ..current = ready(confirmed: false, withImage: false);
      await openDetail(tester, repo);
      expect(find.text('Чтобы опубликовать, осталось:'), findsOneWidget);
      expect(find.text('Добавьте хотя бы одно фото'), findsOneWidget);
      expect(find.widgetWithText(FilledButton, 'Опубликовать'), findsNothing);
    });

    testWidgets('zero mass draft shows the mass hint', (tester) async {
      final repo = LifeRepo()..current = ready(total: '0.000');
      await openDetail(tester, repo);
      expect(find.text('Укажите массу больше нуля'), findsOneWidget);
    });

    testWidgets('publish asks confirmation, sends version, shows server card',
        (tester) async {
      final repo = LifeRepo();
      await openDetail(tester, repo);
      await tester.tap(find.widgetWithText(FilledButton, 'Опубликовать'));
      await tester.pumpAndSettle();
      expect(repo.publishCalls, 0);
      await tester.tap(find.text('Отмена'));
      await tester.pumpAndSettle();
      expect(repo.publishCalls, 0);

      await tester.tap(find.widgetWithText(FilledButton, 'Опубликовать'));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(FilledButton, 'Опубликовать').last);
      await tester.pumpAndSettle();
      expect(repo.publishCalls, 1);
      expect(repo.lastVersion, 3);
      // The result screen shows the server's status and mass, then closes.
      expect(find.text('Партия опубликована'), findsOneWidget);
      expect(find.text(MaterialStatus.available.label), findsWidgets);
      await tester.tap(find.text('К партии'));
      await tester.pumpAndSettle();
      expect(find.text('Партия опубликована'), findsNothing);
      expect(find.text(MaterialStatus.available.label), findsWidgets);
      expect(find.text('Архивировать'), findsOneWidget);
    });

    testWidgets('button is disabled while the request is in flight',
        (tester) async {
      final repo = LifeRepo()..gate = Completer<void>();
      await openDetail(tester, repo);
      await tester.tap(find.widgetWithText(FilledButton, 'Опубликовать'));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(FilledButton, 'Опубликовать').last);
      await tester.pump();
      final btn = tester.widget<FilledButton>(
          find.widgetWithText(FilledButton, 'Публикация…'));
      expect(btn.onPressed, isNull);
      repo.gate!.complete();
      await tester.pumpAndSettle();
      expect(repo.publishCalls, 1);
    });

    testWidgets('version conflict shows current version and refresh',
        (tester) async {
      final repo = LifeRepo()
        ..lifeError = const ApiException(
            code: 'VERSION_CONFLICT',
            message: 'raw',
            statusCode: 409,
            details: {'current_version': 9});
      await openDetail(tester, repo);
      await tester.tap(find.widgetWithText(FilledButton, 'Опубликовать'));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(FilledButton, 'Опубликовать').last);
      await tester.pumpAndSettle();
      expect(find.textContaining('Актуальная версия: 9'), findsOneWidget);
      expect(find.text('Обновить данные'), findsOneWidget);
      final before = repo.getCalls;
      await tester.tap(find.text('Обновить данные'));
      await tester.pumpAndSettle();
      expect(repo.getCalls, greaterThan(before));
    });

    testWidgets('server 422 lists missing items with labels', (tester) async {
      final repo = LifeRepo()
        ..lifeError = const ApiException(
            code: 'PUBLISH_REQUIREMENTS_NOT_MET',
            message: 'raw',
            statusCode: 422,
            details: {
              'missing': ['images', 'confirmation']
            });
      await openDetail(tester, repo);
      await tester.tap(find.widgetWithText(FilledButton, 'Опубликовать'));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(FilledButton, 'Опубликовать').last);
      await tester.pumpAndSettle();
      expect(find.textContaining('Добавьте хотя бы одно фото'), findsOneWidget);
      expect(find.textContaining('images'), findsNothing);
    });

    testWidgets('archive: hidden for draft, ACTIVE_OBLIGATIONS is readable',
        (tester) async {
      final repo = LifeRepo()
        ..current = ready(status: MaterialStatus.partiallyAllocated)
        ..lifeError = const ApiException(
            code: 'ACTIVE_OBLIGATIONS',
            message: 'raw',
            statusCode: 409,
            details: {'held_kg': '20.000', 'reason': 'HELD_RESERVATIONS'});
      await openDetail(tester, repo);
      await tester.tap(find.widgetWithText(OutlinedButton, 'Архивировать'));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(FilledButton, 'Архивировать'));
      await tester.pumpAndSettle();
      expect(repo.archiveCalls, 1);
      expect(find.textContaining('20.000 кг'), findsOneWidget);
      expect(find.textContaining('ACTIVE_OBLIGATIONS'), findsNothing);
    });

    testWidgets('no archive button for a draft', (tester) async {
      await openDetail(tester, LifeRepo());
      expect(find.text('Архивировать'), findsNothing);
    });
  });

  test('re-picking the same file does not add a duplicate', () {
    final repo = RecordingRepo();
    final c = makeContainer(repo);
    final f = PickedPhoto(name: 'a.jpg', bytes: jpegBytes());
    final n = c.read(createMaterialProvider.notifier);
    n.addPhotos([f]);
    n.addPhotos([PickedPhoto(name: 'a.jpg', bytes: jpegBytes())]);
    expect(c.read(createMaterialProvider).photos.length, 1);
  });
}
