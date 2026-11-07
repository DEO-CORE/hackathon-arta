import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:arta/core/config/app_config.dart';
import 'package:arta/core/network/api_client.dart';
import 'package:arta/core/network/api_exception.dart';
import 'package:arta/core/session/session.dart';
import 'package:arta/demo/demo_material_repository.dart';
import 'package:arta/features/analysis/data/analysis_provider.dart';
import 'package:arta/features/analysis/models/analysis_models.dart';
import 'package:arta/features/analysis/presentation/analysis_screen.dart';
import 'package:arta/features/analysis/providers/analysis_providers.dart';
import 'package:arta/features/auth/models/auth_models.dart';
import 'package:arta/features/materials/models/material_enums.dart';
import 'package:arta/features/materials/models/material_input.dart';
import 'package:arta/features/materials/models/material_models.dart';
import 'package:arta/features/materials/models/material_rules.dart';
import 'package:arta/features/materials/providers/material_providers.dart';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/material_fakes.dart';

/// Scripted backend: [gets] are returned in order, the last one repeats.
class FakeBackend implements AnalysisProvider {
  FakeBackend(this.gets, {this.startError});
  final List<Analysis> gets;
  final ApiException? startError;
  int startCalls = 0;
  int getCalls = 0;
  Completer<void>? startGate;

  @override
  Future<AnalysisStart> start(String materialId) async {
    startCalls++;
    if (startGate != null) await startGate!.future;
    if (startError != null) throw startError!;
    return const AnalysisStart(
        analysisId: 'a1', status: AnalysisStatus.pending);
  }

  @override
  Future<Analysis> get(String analysisId) async {
    final i = getCalls < gets.length ? getCalls : gets.length - 1;
    getCalls++;
    return gets[i];
  }
}

Analysis _failed(String code,
        {AnalysisStatus status = AnalysisStatus.failed}) =>
    Analysis(
        id: 'a1',
        materialId: 'm1',
        status: status,
        inputVersion: 1,
        isCurrent: true,
        errorCode: code);

const _result = AnalysisResult(
  color: VisualFeature(
      value: 'blue', description: 'светло-синий', confidence: Level.medium),
  pattern:
      VisualFeature(value: 'solid', description: null, confidence: Level.high),
  texture:
      VisualFeature(value: null, description: null, confidence: Level.unknown),
  reuseOptions: [
    ReuseOption(
        reuseType: 'patchwork_crafts',
        suitability: Level.high,
        reason: 'Однотонные крупные обрезки удобно сшивать.')
  ],
);

Analysis _ok({String mode = 'live', bool current = true}) => Analysis(
    id: 'a1',
    materialId: 'm1',
    status: AnalysisStatus.succeeded,
    inputVersion: 1,
    isCurrent: current,
    mode: mode,
    result: _result);

const _fast = PollingConfig(
    interval: Duration(milliseconds: 100), ceiling: Duration(seconds: 1));

Future<ProviderContainer> _open(
  WidgetTester tester, {
  required AnalysisProvider backend,
  RecordingRepo? repo,
  bool withPhoto = true,
  bool demo = false,
  UserRole role = UserRole.enterprise,
}) async {
  final r = repo ?? RecordingRepo();
  r.serverItem = withPhoto
      ? r.serverItem.copyWith(images: const [
          MaterialImage(
              id: 'i1', mimeType: 'image/jpeg', sizeBytes: 1, sortOrder: 0)
        ])
      : r.serverItem;
  final c = ProviderContainer(overrides: [
    materialRepositoryProvider.overrideWithValue(r),
    analysisBackendProvider.overrideWithValue(backend),
    pollingConfigProvider.overrideWithValue(_fast),
    if (demo)
      appConfigProvider.overrideWithValue(
          const AppConfig(apiBaseUrl: '', useDemoData: true)),
  ]);
  addTearDown(c.dispose);
  c.read(sessionProvider.notifier).signIn(LoginResult(
        accessToken: 't',
        user: AuthUser(
            id: 'u',
            email: 'e@x.test',
            role: role,
            organizationId: 'o',
            active: true),
      ));
  await pumpScreen(tester, c, const AnalysisScreen(materialId: 'm1'));
  return c;
}

void main() {
  testWidgets('no photo: explains it and offers no start button',
      (tester) async {
    final b = FakeBackend([_ok()]);
    await _open(tester, backend: b, withPhoto: false);
    expect(find.text('Для анализа нужно фото.'), findsOneWidget);
    expect(find.text('Проанализировать фото'), findsNothing);
    expect(analysisNotice, contains('не определяет состав'));
    expect(find.text(analysisNotice), findsOneWidget);
    expect(b.startCalls, 0);
  });

  testWidgets(
      'progress: queued then running, then live result without demo marks',
      (tester) async {
    final b = FakeBackend([
      const Analysis(
          id: 'a1',
          materialId: 'm1',
          status: AnalysisStatus.running,
          inputVersion: 1,
          isCurrent: true),
      _ok(),
    ]);
    await _open(tester, backend: b);
    await tester.tap(find.text('Проанализировать фото'));
    await tester.pump();
    await tester.pump();
    expect(find.text('Анализ поставлен в очередь…'), findsOneWidget);
    expect(find.byType(LinearProgressIndicator), findsOneWidget);
    await tester.pump(const Duration(milliseconds: 100));
    await tester.pump();
    expect(find.text('Анализ выполняется…'), findsOneWidget);
    await tester.pump(const Duration(milliseconds: 100));
    await tester.pumpAndSettle();
    expect(find.text('ИИ-результат, требует проверки'), findsOneWidget);
    expect(find.text('Симуляция'), findsNothing);
    expect(find.text('Демо'), findsNothing);
    expect(find.text('Уверенность: средняя'), findsOneWidget);
    expect(find.text('Уверенность: высокая'), findsOneWidget);
    expect(find.text('Уверенность: неизвестно'), findsOneWidget);
    expect(find.text('Неизвестно'), findsWidgets); // unknown texture
    expect(find.text('Почему: Однотонные крупные обрезки удобно сшивать.'),
        findsOneWidget);
  });

  testWidgets('demo result: simulation plate, no percent, never "Подтверждено"',
      (tester) async {
    final repo = DemoMaterialRepository();
    var m = await repo.create(const MaterialCreate(
        name: 'Партия',
        materialType: TextileType.knit,
        condition: MaterialCondition.good,
        city: 'Бишкек',
        totalKg: '5.000'));
    await repo.uploadImage(
        m.id, PickedPhoto(name: 'a.jpg', bytes: jpegBytes()));
    m = await repo.get(m.id);
    final c = ProviderContainer(overrides: [
      appConfigProvider.overrideWithValue(
          const AppConfig(apiBaseUrl: '', useDemoData: true)),
      materialRepositoryProvider.overrideWithValue(repo),
      analysisBackendProvider.overrideWithValue(
          DemoAnalysisProvider(materials: repo, delay: Duration.zero)),
      pollingConfigProvider.overrideWithValue(_fast),
    ]);
    addTearDown(c.dispose);
    c.read(sessionProvider.notifier).signIn(const LoginResult(
          accessToken: 't',
          user: AuthUser(
              id: 'u',
              email: 'e@x.test',
              role: UserRole.enterprise,
              organizationId: 'o',
              active: true),
        ));
    await pumpScreen(tester, c, AnalysisScreen(materialId: m.id));
    expect(find.text('Симуляция'), findsOneWidget);
    await tester.tap(find.text('Проанализировать фото'));
    for (var i = 0; i < 6; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }
    await tester.pumpAndSettle();

    expect(find.text('Симуляция'), findsOneWidget);
    expect(find.text('Демо: смоделированный результат.'), findsOneWidget);
    expect(find.text('Предложение ИИ'), findsWidgets);
    expect(find.text('Состав: Неизвестно — по фото не определяется.'),
        findsOneWidget);
    expect(find.textContaining('Почему:'), findsWidgets);
    expect(find.textContaining('Применимость:'), findsWidgets);
    // Words only: no percentages anywhere on the screen.
    expect(find.textContaining('%'), findsNothing);
    // Nothing is confirmed until the person presses the button.
    expect(find.textContaining('Подтверждено'), findsNothing);
    expect(find.text('Не подтверждено'), findsOneWidget);
    // The human values are the material's own, not AI's.
    expect(find.textContaining('Трикотаж'), findsOneWidget);

    await tester.ensureVisible(find.text('Подтвердить характеристики'));
    await tester.tap(find.text('Подтвердить характеристики'));
    await tester.pumpAndSettle();
    expect(find.textContaining('Подтверждено человеком'), findsOneWidget);
    expect(find.text('Подтвердить характеристики'), findsNothing);
    expect((await repo.get(m.id)).isConfirmationCurrent, isTrue);
  });

  testWidgets('mock/fallback mode from a live API is labelled as simulation',
      (tester) async {
    final b = FakeBackend([_ok(mode: 'fallback')]);
    await _open(tester, backend: b);
    await tester.tap(find.text('Проанализировать фото'));
    await tester.pumpAndSettle(const Duration(milliseconds: 200));
    expect(find.text('Симуляция'), findsOneWidget);
    expect(
        find.text('Резервный пример, не анализ вашего фото.'), findsOneWidget);
  });

  testWidgets('failed: server text, retry starts a new job once',
      (tester) async {
    final b = FakeBackend([_failed('PROVIDER_TIMEOUT')]);
    await _open(tester, backend: b);
    await tester.tap(find.text('Проанализировать фото'));
    await tester.pumpAndSettle(const Duration(milliseconds: 200));
    expect(find.text('Анализ не удался.'), findsOneWidget);
    expect(find.text(analysisErrorTexts['PROVIDER_TIMEOUT']!), findsOneWidget);
    expect(find.text('Вы можете подтвердить характеристики вручную.'),
        findsOneWidget);
    expect(find.text('Подтвердить характеристики'), findsOneWidget);

    b.startGate = Completer<void>();
    await tester.tap(find.text('Повторить'));
    await tester.pump();
    // In flight: the retry button is gone, so no second submit is possible.
    expect(find.text('Повторить'), findsNothing);
    expect(b.startCalls, 2);
    b.startGate!.complete();
    await tester.pumpAndSettle(const Duration(milliseconds: 200));
  });

  testWidgets('interrupted is shown as failed with a restart button',
      (tester) async {
    final b = FakeBackend([
      _failed('INTERRUPTED', status: AnalysisStatus.interrupted),
    ]);
    await _open(tester, backend: b);
    await tester.tap(find.text('Проанализировать фото'));
    await tester.pumpAndSettle(const Duration(milliseconds: 200));
    expect(find.text('Анализ не удался.'), findsOneWidget);
    expect(find.text('Анализ прерван. Запустите заново.'), findsOneWidget);
    expect(find.text('Запустить заново'), findsOneWidget);
  });

  testWidgets('refused / auth errors do not offer a pointless retry',
      (tester) async {
    final b = FakeBackend([_failed('PROVIDER_REFUSED')]);
    await _open(tester, backend: b);
    await tester.tap(find.text('Проанализировать фото'));
    await tester.pumpAndSettle(const Duration(milliseconds: 200));
    expect(find.text('Повторить'), findsNothing);
    expect(find.text('Запустить заново'), findsNothing);
  });

  testWidgets('409 NO_IMAGES from the server is explained', (tester) async {
    final b = FakeBackend([_ok()],
        startError: const ApiException(
            code: 'PRECONDITION_FAILED',
            message: 'x',
            statusCode: 409,
            details: {'reason': 'NO_IMAGES'}));
    await _open(tester, backend: b);
    await tester.tap(find.text('Проанализировать фото'));
    await tester.pumpAndSettle();
    expect(find.text('Добавьте хотя бы одно фото партии.'), findsOneWidget);
  });

  testWidgets('stale result hides suggestions', (tester) async {
    final b = FakeBackend([_ok(current: false)]);
    await _open(tester, backend: b);
    await tester.tap(find.text('Проанализировать фото'));
    await tester.pumpAndSettle(const Duration(milliseconds: 200));
    expect(find.text('Данные партии изменились. Запустите анализ заново.'),
        findsOneWidget);
    expect(find.text('Предложения ИИ'), findsNothing);
  });

  testWidgets('polling stops at the ceiling and can be resumed',
      (tester) async {
    final b = FakeBackend([
      const Analysis(
          id: 'a1',
          materialId: 'm1',
          status: AnalysisStatus.running,
          inputVersion: 1,
          isCurrent: true),
    ]);
    await _open(tester, backend: b);
    await tester.tap(find.text('Проанализировать фото'));
    for (var i = 0; i < 14; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }
    expect(find.text('Анализ занимает дольше обычного'), findsOneWidget);
    final calls = b.getCalls;
    await tester.pump(const Duration(seconds: 2));
    expect(b.getCalls, calls); // stopped
    await tester.tap(find.text('Проверить снова'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
    expect(b.getCalls, greaterThan(calls));
    expect(b.startCalls, 1); // same analysis, no new job
    // Let polling reach the ceiling again so no timer outlives the test.
    for (var i = 0; i < 14; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }
    expect(find.text('Проверить снова'), findsOneWidget);
  });

  testWidgets('buyer cannot use the analysis screen', (tester) async {
    final b = FakeBackend([_ok()]);
    await _open(tester, backend: b, role: UserRole.buyer);
    expect(
        find.text('Анализ доступен только владельцу партии.'), findsOneWidget);
    expect(find.text('Проанализировать фото'), findsNothing);
  });

  test('leaving the screen stops polling (controller is disposed)', () async {
    final b = FakeBackend([
      const Analysis(
          id: 'a1',
          materialId: 'm1',
          status: AnalysisStatus.running,
          inputVersion: 1,
          isCurrent: true),
    ]);
    final c = ProviderContainer(overrides: [
      analysisBackendProvider.overrideWithValue(b),
      pollingConfigProvider.overrideWithValue(const PollingConfig(
          interval: Duration(milliseconds: 20), ceiling: Duration(seconds: 5))),
    ]);
    addTearDown(c.dispose);
    final sub = c.listen(analysisControllerProvider('m1'), (_, __) {});
    await c.read(analysisControllerProvider('m1').notifier).start();
    await Future<void>.delayed(const Duration(milliseconds: 100));
    final seen = b.getCalls;
    expect(seen, greaterThan(0));
    sub.close();
    await Future<void>.delayed(const Duration(milliseconds: 50));
    final after = b.getCalls;
    await Future<void>.delayed(const Duration(milliseconds: 100));
    expect(b.getCalls, after);
  });

  group('contract', () {
    test('POST /ai/analyze body is only material_id', () async {
      final adapter = _Adapter({
        'analysis_id': 'a1',
        'status': 'pending',
        'input_version': 4,
      });
      final client = ApiClient(
          baseUrl: 'http://x', tokenReader: () => 't', onUnauthorized: () {});
      client.dio.httpClientAdapter = adapter;
      final s = await ApiAnalysisProvider(client).start('m1');
      expect(s.analysisId, 'a1');
      expect(adapter.last!.path, '/ai/analyze');
      expect(adapter.last!.data, {'material_id': 'm1'});
    });

    test('a reuse option without a valid reason invalidates the result', () {
      Map<String, Object?> body(String reason) => {
            'id': 'a',
            'material_id': 'm',
            'status': 'succeeded',
            'input_version': 1,
            'is_current': true,
            'result': {
              'visual_features': {
                'color': {'primary': 'blue', 'confidence': 'high'},
                'pattern': {'value': 'solid', 'confidence': 'high'},
                'apparent_texture': {'value': null, 'confidence': 'unknown'},
              },
              'reuse_options': [
                {
                  'reuse_type': 'cleaning_rags',
                  'suitability': 'high',
                  'reason': reason
                }
              ],
            },
          };
      expect(() => Analysis.fromJson(body('коротко')),
          throwsA(isA<ApiException>()));
      expect(Analysis.fromJson(body('Достаточно длинная причина.')).result,
          isNotNull);
    });

    test('bundled demo fixture equals docs/fixtures/demo-analysis.json', () {
      final src = File('../docs/fixtures/demo-analysis.json');
      if (!src.existsSync()) return; // running outside the monorepo
      expect(
          jsonDecode(File('assets/demo/demo-analysis.json').readAsStringSync()),
          jsonDecode(src.readAsStringSync()));
    });

    test('unknown status maps to a failure state', () {
      expect(AnalysisStatus.parse('weird').isFailure, isTrue);
      expect(AnalysisStatus.parse('interrupted').isFailure, isTrue);
    });
  });
}

class _Adapter implements HttpClientAdapter {
  _Adapter(this.body);
  final Object body;
  RequestOptions? last;

  @override
  Future<ResponseBody> fetch(RequestOptions options,
      Stream<Uint8List>? requestStream, Future<void>? cancelFuture) async {
    last = options;
    return ResponseBody.fromString(jsonEncode(body), 202, headers: {
      Headers.contentTypeHeader: ['application/json']
    });
  }

  @override
  void close({bool force = false}) {}
}
