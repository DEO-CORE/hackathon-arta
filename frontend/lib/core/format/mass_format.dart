/// Display-only formatting of server decimal strings. Never parses to
/// double, never rounds: precision in models and the API is untouched.
///
/// "120.500" -> "120,5", "12.5" -> "12,5", "7.000" -> "7", "1250.5" ->
/// "1 250,5" (no-break space). Unparseable input is returned unchanged so a
/// contract violation stays visible instead of turning into "0".
String formatDecimal(String value) {
  final m = RegExp(r'^(-?)(\d+)(?:\.(\d+))?$').firstMatch(value.trim());
  if (m == null) return value;
  final sign = m.group(1)!;
  final whole = m.group(2)!.replaceFirst(RegExp(r'^0+(?=\d)'), '');
  final frac = (m.group(3) ?? '').replaceFirst(RegExp(r'0+$'), '');
  final grouped = whole.replaceAllMapped(
    RegExp(r'\B(?=(\d{3})+(?!\d))'),
    (_) => ' ',
  );
  final isZero = whole == '0' && frac.isEmpty;
  return '${isZero ? '' : sign}$grouped${frac.isEmpty ? '' : ',$frac'}';
}

/// "120.500" -> "120,5 кг" (no-break space before the unit).
String formatKg(String value) => '${formatDecimal(value)} кг';
