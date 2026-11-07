import 'dart:typed_data';

import 'package:arta/features/materials/models/material_models.dart';
import 'package:arta/features/materials/models/material_rules.dart';
import 'package:arta/features/materials/presentation/material_form_model.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('mass validation', () {
    expect(validateMassKg(''), isNotNull);
    expect(validateMassKg('0'), isNotNull);
    expect(validateMassKg('0.000'), isNotNull);
    expect(validateMassKg('-1'), isNotNull);
    expect(validateMassKg('1.2345'), isNotNull);
    expect(validateMassKg('abc'), isNotNull);
    expect(validateMassKg('12,5'), isNull);
    expect(validateMassKg('0.001'), isNull);
  });

  test('price is optional and limited to 2 decimals', () {
    expect(validatePriceKgs(''), isNull);
    expect(validatePriceKgs('45.00'), isNull);
    expect(validatePriceKgs('45.001'), isNotNull);
    expect(validatePriceKgs('-1'), isNotNull);
  });

  test('photo validation by signature and size', () {
    final jpeg = PickedPhoto(
        name: 'a.jpg', bytes: Uint8List.fromList([0xFF, 0xD8, 0xFF, 0xE0, 1]));
    final gif = PickedPhoto(
        name: 'a.gif', bytes: Uint8List.fromList(List.filled(20, 0x47)));
    final big = PickedPhoto(
        name: 'big.jpg',
        bytes: Uint8List(maxPhotoBytes + 1)
          ..setRange(0, 3, [0xFF, 0xD8, 0xFF]));
    final webp = PickedPhoto(
        name: 'a.webp',
        bytes: Uint8List.fromList(
            [...'RIFF'.codeUnits, 0, 0, 0, 0, ...'WEBP'.codeUnits, 0]));
    expect(validatePhoto(jpeg), isNull);
    expect(validatePhoto(webp), isNull);
    expect(validatePhoto(gif), isNotNull);
    expect(validatePhoto(big), contains('10 МБ'));
  });

  test('canonDecimal compares equal masses written differently', () {
    expect(canonDecimal('12.5', 3), canonDecimal('12.500', 3));
    expect(canonDecimal('12.5', 3), isNot(canonDecimal('12.501', 3)));
  });

  test('MaterialItem parsing keeps decimals as strings and rejects numbers',
      () {
    final json = {
      'id': 'x',
      'name': 'n',
      'status': 'weird',
      'version': 2,
      'material_type': 'cotton',
      'price_per_kg': null,
      'balance': {
        'total_kg': '1.000',
        'available_kg': '1.000',
        'held_kg': '0.000',
        'transferred_kg': '0.000',
        'internally_used_kg': '0.000',
      },
      'images': [],
    };
    final m = MaterialItem.fromJson(json);
    expect(m.availableKg, '1.000');
    expect(m.pricePerKg, isNull);
    expect(m.status.label, 'Статус неизвестен');
    json['balance'] = {...(json['balance'] as Map), 'total_kg': 1.0};
    expect(() => MaterialItem.fromJson(json), throwsA(anything));
  });
}
