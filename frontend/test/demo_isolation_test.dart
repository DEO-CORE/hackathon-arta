import 'dart:typed_data';

import 'package:arta/core/config/app_config.dart';
import 'package:arta/core/network/api_client.dart';
import 'package:arta/core/session/session.dart';
import 'package:arta/demo/demo_material_repository.dart';
import 'package:arta/features/auth/models/auth_models.dart';
import 'package:arta/features/materials/data/material_repository.dart';
import 'package:arta/features/materials/presentation/catalog_screen.dart';
import 'package:arta/features/materials/providers/material_providers.dart';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

class _Offline implements HttpClientAdapter {
  int calls = 0;
  @override
  Future<ResponseBody> fetch(RequestOptions options,
      Stream<Uint8List>? requestStream, Future<void>? cancelFuture) async {
    calls++;
    throw DioException(
        requestOptions: options, type: DioExceptionType.connectionError);
  }

  @override
  void close({bool force = false}) {}
}

void main() {
  test('default config never selects the demo repository', () {
    final c = ProviderContainer();
    addTearDown(c.dispose);
    expect(c.read(appConfigProvider).useDemoData, isFalse);
    expect(c.read(materialRepositoryProvider), isA<ApiMaterialRepository>());
  });

  test('demo repository only with explicit USE_DEMO_DATA', () {
    final c = ProviderContainer(overrides: [
      appConfigProvider.overrideWithValue(
          const AppConfig(apiBaseUrl: '', useDemoData: true)),
    ]);
    addTearDown(c.dispose);
    expect(c.read(materialRepositoryProvider), isA<DemoMaterialRepository>());
  });

  test('a base URL alone does not enable demo data', () {
    final c = ProviderContainer(overrides: [
      appConfigProvider.overrideWithValue(
          const AppConfig(apiBaseUrl: 'http://x', useDemoData: false)),
    ]);
    addTearDown(c.dispose);
    expect(c.read(materialRepositoryProvider), isA<ApiMaterialRepository>());
  });

  testWidgets('network failure shows an error with retry, not demo data',
      (tester) async {
    final offline = _Offline();
    final container = ProviderContainer(overrides: [
      appConfigProvider.overrideWithValue(
          const AppConfig(apiBaseUrl: 'http://test', useDemoData: false)),
      apiClientProvider.overrideWithValue(ApiClient(
        baseUrl: 'http://test',
        tokenReader: () => 't',
        onUnauthorized: () {},
        dio: Dio()..httpClientAdapter = offline,
      )),
    ]);
    addTearDown(container.dispose);
    container.read(sessionProvider.notifier).signIn(const LoginResult(
        accessToken: 't',
        user: AuthUser(
            id: 'u',
            email: 'e@x.test',
            role: UserRole.enterprise,
            organizationId: 'o',
            active: true)));
    await tester.pumpWidget(UncontrolledProviderScope(
        container: container, child: const MaterialApp(home: CatalogScreen())));
    await tester.pumpAndSettle();

    expect(offline.calls, 1);
    expect(find.text('Повторить'), findsOneWidget);
    expect(find.textContaining('Проверьте соединение'), findsOneWidget);
    expect(find.textContaining('Демо'), findsNothing);
    expect(find.textContaining('демо'), findsNothing);

    await tester.tap(find.text('Повторить'));
    await tester.pumpAndSettle();
    expect(offline.calls, 2, reason: 'retry must hit the network again');
    expect(find.textContaining('Демо'), findsNothing);
  });
}
