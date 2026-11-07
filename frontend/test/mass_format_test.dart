import 'package:arta/core/format/mass_format.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('trailing zeros are dropped, comma is the separator', () {
    expect(formatKg('120.500'), '120,5 кг');
    expect(formatKg('12.5'), '12,5 кг');
    expect(formatKg('7'), '7 кг');
    expect(formatKg('7.000'), '7 кг');
    expect(formatKg('0.000'), '0 кг');
    expect(formatKg('0.125'), '0,125 кг');
  });

  test('thousands use a no-break space and nothing is rounded', () {
    expect(formatDecimal('1250.500'), '1 250,5');
    expect(formatDecimal('1234567.001'), '1 234 567,001');
  });

  test('invalid input is returned unchanged', () {
    expect(formatDecimal('abc'), 'abc');
    expect(formatDecimal('1e3'), '1e3');
  });
}
