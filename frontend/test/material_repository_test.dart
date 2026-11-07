import 'dart:convert';
import 'dart:typed_data';

import 'package:arta/core/network/api_client.dart';
import 'package:arta/core/network/api_exception.dart';
import 'package:arta/features/materials/data/material_repository.dart';
import 'package:arta/features/materials/models/material_enums.dart';
import 'package:arta/features/materials/models/material_input.dart';
import 'package:arta/features/materials/models/material_rules.dart';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';

class _Adapter implements HttpClientAdapter {
  final requests = <RequestOptions>[];
  int status = 200;
  Object body = {};

  @override
  Future<ResponseBody> fetch(RequestOptions options,
      Stream<Uint8List>? requestStream, Future<void>? cancelFuture) async {
    requests.add(options);
    return ResponseBody.fromString(jsonEncode(body), status, headers: {
      Headers.contentTypeHeader: ['application/json']
    });
  }

  @override
  void close({bool force = false}) {}
}

Map<String, Object?> materialJson({int version = 1}) => {
      'id': 'm1',
      'name': 'Демо-партия',
      'status': 'draft',
      'version': version,
      'balance': {
        'total_kg': '10.000',
        'available_kg': '10.000',
        'held_kg': '0.000',
        'transferred_kg': '0.000',
        'internally_used_kg': '0.000',
      },
      'images': [],
    };

void main() {
  late _Adapter adapter;
  late ApiMaterialRepository repo;

  setUp(() {
    adapter = _Adapter();
    final client = ApiClient(
      baseUrl: 'http://test',
      tokenReader: () => 'tok',
      onUnauthorized: () {},
      dio: Dio()..httpClientAdapter = adapter,
    );
    repo = ApiMaterialRepository(client);
  });

  test('list sends paging and status query with Bearer token', () async {
    adapter.body = {
      'items': [materialJson()],
      'page': 2,
      'page_size': 20,
      'total': 21
    };
    final page = await repo.list(status: MaterialStatus.draft, page: 2);
    final r = adapter.requests.single;
    expect(r.path, '/materials');
    expect(r.queryParameters, {'page': 2, 'page_size': 20, 'status': 'draft'});
    expect(r.headers['Authorization'], 'Bearer tok');
    expect(page.total, 21);
  });

  test('create posts decimal strings', () async {
    adapter.status = 201;
    adapter.body = materialJson();
    await repo.create(const MaterialCreate(
      name: 'A',
      materialType: TextileType.cotton,
      condition: MaterialCondition.good,
      city: 'Бишкек',
      totalKg: '12.500',
      pricePerKg: '45.00',
    ));
    final data = adapter.requests.single.data as Map;
    expect(data['total_kg'], '12.500');
    expect(data['price_per_kg'], '45.00');
    expect(data.containsKey('composition'), isFalse);
  });

  test('patch puts version in the body and no If-Match', () async {
    adapter.body = materialJson(version: 4);
    await repo.patch('m1',
        const MaterialPatch(version: 3, fields: {'city': null, 'name': 'B'}));
    final r = adapter.requests.single;
    expect(r.method, 'PATCH');
    expect(r.data, {'version': 3, 'city': null, 'name': 'B'});
    expect(r.headers.containsKey('If-Match'), isFalse);
  });

  test('409 VERSION_CONFLICT maps to ApiException with current_version',
      () async {
    adapter.status = 409;
    adapter.body = {
      'error': {
        'code': 'VERSION_CONFLICT',
        'message': 'Устарело',
        'details': {'current_version': 5},
        'request_id': 'r1',
      }
    };
    await expectLater(
      repo.patch('m1', const MaterialPatch(version: 1, fields: {'name': 'x'})),
      throwsA(isA<ApiException>()
          .having((e) => e.code, 'code', 'VERSION_CONFLICT')
          .having((e) => e.details?['current_version'], 'v', 5)),
    );
  });

  test('upload sends multipart to the images route', () async {
    adapter.status = 201;
    adapter.body = {
      'image': {
        'id': 'i1',
        'mime_type': 'image/jpeg',
        'size_bytes': 3,
        'sort_order': 0
      },
      'material_version': 2,
    };
    final res = await repo.uploadImage(
        'm1', PickedPhoto(name: 'a.jpg', bytes: Uint8List.fromList([1, 2, 3])));
    final r = adapter.requests.single;
    expect(r.path, '/materials/m1/images');
    expect(r.data, isA<FormData>());
    expect(res.materialVersion, 2);
  });

  test('malformed response becomes INVALID_RESPONSE', () async {
    adapter.body = {'unexpected': true};
    await expectLater(
      repo.get('m1'),
      throwsA(isA<ApiException>()
          .having((e) => e.code, 'code', 'INVALID_RESPONSE')),
    );
  });
}
