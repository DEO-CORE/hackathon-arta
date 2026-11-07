import 'dart:typed_data';

/// Client-side pre-checks. The server stays the authority and re-validates.
final _massRe = RegExp(r'^\d{1,9}(\.\d{1,3})?$');
final _moneyRe = RegExp(r'^\d{1,12}(\.\d{1,2})?$');

String normalizeDecimal(String raw) => raw.trim().replaceAll(',', '.');

bool _isZero(String s) => s.replaceAll(RegExp(r'[0.]'), '').isEmpty;

/// Returns an error text or null. Mass is positive with up to 3 decimals.
String? validateMassKg(String? raw) {
  final v = normalizeDecimal(raw ?? '');
  if (v.isEmpty) return 'Укажите массу в кг.';
  if (!_massRe.hasMatch(v)) return _massFormatError(v);
  if (_isZero(v)) return 'Масса должна быть больше нуля.';
  return null;
}

/// Draft-level mass check: zero is a valid draft value (api.md 18.4); the
/// positive-mass rule applies only at publish time.
String? validateDraftMassKg(String? raw) {
  final v = normalizeDecimal(raw ?? '');
  if (v.isEmpty) return 'Укажите массу в кг.';
  if (!_massRe.hasMatch(v)) return _massFormatError(v);
  return null;
}

/// Optional price in KGS, non-negative, up to 2 decimals.
String? validatePriceKgs(String? raw) {
  final v = normalizeDecimal(raw ?? '');
  if (v.isEmpty) return null;
  if (!_moneyRe.hasMatch(v)) return _priceFormatError(v);
  return null;
}

/// [emptyMessage] is a full sentence, e.g. "Укажите город." (no field prefix).
String? validateRequiredText(String? raw,
    {required String emptyMessage, int max = 200}) {
  final v = (raw ?? '').trim();
  if (v.isEmpty) return emptyMessage;
  if (v.length > max) return tooLongMessage(max);
  return null;
}

String tooLongMessage(int max) =>
    'Слишком длинное значение. Максимум $max символов.';

String _massFormatError(String v) {
  if (v.startsWith('-')) return 'Значение не может быть отрицательным.';
  if (RegExp(r'^\d+\.\d{4,}$').hasMatch(v)) {
    return 'Укажите не больше трёх знаков после запятой.';
  }
  return 'Введите число, например 12,5.';
}

String _priceFormatError(String v) {
  if (v.startsWith('-')) return 'Значение не может быть отрицательным.';
  if (RegExp(r'^\d+\.\d{3,}$').hasMatch(v)) {
    return 'Укажите не больше двух знаков после запятой.';
  }
  return 'Введите число, например 120,50.';
}

String? validateOptionalText(String? raw, {int max = 200}) {
  final v = (raw ?? '').trim();
  if (v.length > max) return tooLongMessage(max);
  return null;
}

const maxPhotos = 5;
const maxPhotoBytes = 10 * 1024 * 1024;

class PickedPhoto {
  const PickedPhoto({required this.name, required this.bytes});
  final String name;
  final Uint8List bytes;
}

/// Checks size and file signature (JPEG, PNG, WebP). Returns an error or null.
String? validatePhoto(PickedPhoto p) {
  if (p.bytes.isEmpty) return '«${p.name}»: файл пустой';
  if (p.bytes.length > maxPhotoBytes) {
    return '«${p.name}»: больше 10 МБ';
  }
  if (!_hasKnownSignature(p.bytes)) {
    return '«${p.name}»: допустимы только JPEG, PNG и WebP';
  }
  return null;
}

bool _hasKnownSignature(Uint8List b) {
  final jpeg = b.length > 3 && b[0] == 0xFF && b[1] == 0xD8 && b[2] == 0xFF;
  final png = b.length > 8 &&
      b[0] == 0x89 &&
      b[1] == 0x50 &&
      b[2] == 0x4E &&
      b[3] == 0x47;
  final webp = b.length > 12 &&
      b[0] == 0x52 && // R
      b[1] == 0x49 && // I
      b[2] == 0x46 && // F
      b[3] == 0x46 && // F
      b[8] == 0x57 && // W
      b[9] == 0x45 && // E
      b[10] == 0x42 && // B
      b[11] == 0x50; // P
  return jpeg || png || webp;
}
