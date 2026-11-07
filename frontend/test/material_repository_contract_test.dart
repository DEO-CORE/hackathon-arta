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

Map<String, Object?> owner([Map<String, Object?> over = const {}]) => {
      'id': 'm1',
      'name': 'N',
      'status': 'draft',
      'version': 1,
      'material_type': 'cotton',
      'condition': 'good',
      'city': 'Бишкек',
      'price_per_kg': '45.00',
      'balance': {
        'total_kg': '120.500',
        'available_kg': '120.500',
        'held_kg': '0.000',
        'transferred_kg': '0.000',
        'internally_used_kg': '0.000',
      },
      'images': [],
      ...over,
    };

void main() {
  late _Adapter a;
  late ApiMaterialRepository repo;
  setUp(() {
    a = _Adapter();
    repo = ApiMaterialRepository(ApiClient(
      baseUrl: 'http://test',
      tokenReader: () => 'tok',
      onUnauthorized: () {},
      dio: Dio()..httpClientAdapter = a,
    ));
  });

  group('routes and methods (api.md 18.3-18.7)', () {
    test('every call uses the documented method and path', () async {
      a.body = {'items': [], 'page': 1, 'page_size': 20, 'total': 0};
      await repo.list();
      a.body = owner();
      await repo.get('m1');
      await repo.create(const MaterialCreate(
          name: 'n',
          materialType: TextileType.cotton,
          condition: MaterialCondition.good,
          city: 'c',
          totalKg: '1'));
      await repo.patch(
          'm1', const MaterialPatch(version: 1, fields: {'name': 'x'}));
      await repo.confirm('m1', version: 1);
      a.body = {
        'image': {
          'id': 'i',
          'mime_type': 'image/jpeg',
          'size_bytes': 1,
          'sort_order': 0
        },
        'material_version': 2
      };
      await repo.uploadImage(
          'm1', PickedPhoto(name: 'a.jpg', bytes: Uint8List(4)));
      a.body = {
        'url': 'https://s.test/x',
        'expires_at': '2026-11-07T10:00:00Z'
      };
      await repo.imageUrl('m1', 'i1');

      final got = [for (final r in a.requests) '${r.method} ${r.path}'];
      expect(got, [
        'GET /materials',
        'GET /materials/m1',
        'POST /materials',
        'PATCH /materials/m1',
        'POST /materials/m1/confirm',
        'POST /materials/m1/images',
        'GET /materials/m1/images/i1/url',
      ]);
      // Never PUT, never a free status PATCH.
      expect(a.requests.any((r) => r.method == 'PUT' || r.method == 'DELETE'),
          isFalse);
    });

    test('list sends status only when filtered and always page params',
        () async {
      a.body = {'items': [], 'page': 2, 'page_size': 20, 'total': 0};
      await repo.list(page: 2);
      await repo.list(status: MaterialStatus.partiallyAllocated);
      expect(a.requests[0].queryParameters, {'page': 2, 'page_size': 20});
      expect(a.requests[1].queryParameters['status'], 'partially_allocated');
    });

    test('patch body = version + only given fields, no status/balance',
        () async {
      a.body = owner();
      await repo.patch(
          'm1',
          const MaterialPatch(
              version: 3, fields: {'city': 'Ош', 'composition': null}));
      final body = a.requests.single.data as Map;
      expect(body, {'version': 3, 'city': 'Ош', 'composition': null});
      expect(body.containsKey('status'), isFalse);
      expect(a.requests.single.headers.containsKey('If-Match'), isFalse);
    });

    test('upload is multipart under field "file"', () async {
      a.body = {
        'image': {
          'id': 'i',
          'mime_type': 'image/png',
          'size_bytes': 1,
          'sort_order': 0
        },
        'material_version': 2
      };
      await repo.uploadImage(
          'm1', PickedPhoto(name: 'a.png', bytes: Uint8List(4)));
      final form = a.requests.single.data as FormData;
      expect(form.files.single.key, 'file');
    });
  });

  group('decimals stay strings', () {
    test('create sends mass and price as JSON strings', () async {
      a.body = owner();
      await repo.create(const MaterialCreate(
          name: 'n',
          materialType: TextileType.cotton,
          condition: MaterialCondition.good,
          city: 'c',
          totalKg: '12.500',
          pricePerKg: '45.00'));
      final body = a.requests.single.data as Map;
      expect(body['total_kg'], isA<String>());
      expect(body['price_per_kg'], isA<String>());
      expect(body['total_kg'], '12.500');
    });

    test('values are returned verbatim (no 120.5 reformatting)', () async {
      a.body = owner();
      final m = await repo.get('m1');
      expect(m.balance!.totalKg, '120.500');
      expect(m.pricePerKg, '45.00');
      expect(m.availableKg, isA<String>());
    });

    test('JSON number for mass or price is INVALID_RESPONSE', () async {
      a.body = owner({'price_per_kg': 45.0});
      await expectLater(repo.get('m1'), throwsA(_code('INVALID_RESPONSE')));
      a.body = owner({
        'balance': {
          'total_kg': 120.5,
          'available_kg': '1',
          'held_kg': '0',
          'transferred_kg': '0',
          'internally_used_kg': '0'
        }
      });
      await expectLater(repo.get('m1'), throwsA(_code('INVALID_RESPONSE')));
    });

    test('non-numeric decimal string is INVALID_RESPONSE', () async {
      a.body = owner({'price_per_kg': 'free'});
      await expectLater(repo.get('m1'), throwsA(_code('INVALID_RESPONSE')));
    });
  });

  group('tolerant reader, strict contract', () {
    test('unknown enum values become unknown, nothing crashes', () async {
      a.body = owner({
        'status': 'frozen_by_future_backend',
        'material_type': 'bamboo',
        'condition': 'haunted',
      });
      final m = await repo.get('m1');
      expect(m.status, MaterialStatus.unknown);
      expect(m.materialType, TextileType.unknown);
      expect(m.condition, MaterialCondition.unknown);
    });

    test('unknown extra fields are ignored', () async {
      a.body = owner({
        'new_server_field': {'x': 1},
        'confirmed_by': 'u'
      });
      final m = await repo.get('m1');
      expect(m.id, 'm1');
    });

    test('public view (no balance) parses and is not an owner view', () async {
      a.body = {
        'id': 'p1',
        'name': 'N',
        'status': 'available',
        'version': 2,
        'available_kg': '7.000',
        'organization_name': 'Демо-цех',
        'images': [],
      };
      final m = await repo.get('p1');
      expect(m.isOwnerView, isFalse);
      expect(m.availableKg, '7.000');
    });

    test('malformed bodies map to INVALID_RESPONSE', () async {
      for (final bad in <Object>[
        [],
        'text',
        {'id': 'm1'},
        owner({'version': '1'}),
        owner({
          'images': [1, 2]
        }),
        owner({'name': null}),
      ]) {
        a.body = bad;
        await expectLater(repo.get('m1'), throwsA(_code('INVALID_RESPONSE')),
            reason: jsonEncode(bad));
      }
      a.body = {'items': 'x', 'page': 1, 'page_size': 20, 'total': 0};
      await expectLater(repo.list(), throwsA(_code('INVALID_RESPONSE')));
    });

    test('error envelope exposes code/details; no raw body leaks', () async {
      a.status = 422;
      a.body = {
        'error': {
          'code': 'VALIDATION_ERROR',
          'message': 'Проверьте заполненные поля.',
          'details': {
            'errors': [
              {'field': 'city', 'code': 'too_long', 'message': 'Длинно.'}
            ]
          },
          'request_id': 'r1'
        }
      };
      try {
        await repo.get('m1');
        fail('should throw');
      } on ApiException catch (e) {
        expect(e.statusCode, 422);
        expect(e.fieldErrors, {'city': 'Длинно.'});
        expect(e.toString(), isNot(contains('Traceback')));
      }
      a.status = 500;
      a.body = '<html>Traceback (most recent call last)</html>';
      try {
        await repo.get('m1');
        fail('should throw');
      } on ApiException catch (e) {
        expect(e.message, isNot(contains('Traceback')));
        expect(e.code, 'UNKNOWN');
      }
    });
  });
}

Matcher _code(String c) => isA<ApiException>().having((e) => e.code, 'code', c);
