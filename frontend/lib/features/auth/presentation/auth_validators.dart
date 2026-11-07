final _emailRe = RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$');

String? validateEmail(String? v) {
  final s = v?.trim() ?? '';
  if (s.isEmpty) return 'Укажите email.';
  if (s.length > 254 || !_emailRe.hasMatch(s)) {
    return 'Введите email в формате name@example.com.';
  }
  return null;
}

/// Length bounds follow docs/api.md 6.1 (10..128); the server stays authoritative.
String? validateNewPassword(String? v) {
  final s = v ?? '';
  if (s.length < 10) return 'Не менее 10 символов';
  if (s.length > 128) return 'Не более 128 символов';
  return null;
}

String? validateRequired(String? v,
    {int max = 200, required String emptyMessage}) {
  final s = v?.trim() ?? '';
  if (s.isEmpty) return emptyMessage;
  if (s.length > max) {
    return 'Слишком длинное значение. Максимум $max символов.';
  }
  return null;
}
