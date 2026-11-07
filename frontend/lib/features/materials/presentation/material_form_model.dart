import 'package:flutter/material.dart';

import '../models/material_enums.dart';
import '../models/material_input.dart';
import '../models/material_models.dart';
import '../models/material_rules.dart';

/// Holds form controllers and selections; shared by create and edit screens.
class MaterialFormModel extends ChangeNotifier {
  MaterialFormModel([MaterialItem? initial])
      : name = TextEditingController(text: initial?.name ?? ''),
        mass = TextEditingController(text: initial?.balance?.totalKg ?? ''),
        city = TextEditingController(text: initial?.city ?? ''),
        price = TextEditingController(text: initial?.pricePerKg ?? ''),
        composition = TextEditingController(text: initial?.composition ?? ''),
        scrapSize = TextEditingController(text: initial?.scrapSize ?? ''),
        _type = _known(initial?.materialType),
        _condition = initial?.condition == MaterialCondition.unknown
            ? null
            : initial?.condition;

  static TextileType? _known(TextileType? t) =>
      t == TextileType.unknown ? null : t;

  final TextEditingController name;
  final TextEditingController mass;
  final TextEditingController city;
  final TextEditingController price;
  final TextEditingController composition;
  final TextEditingController scrapSize;
  TextileType? _type;
  MaterialCondition? _condition;

  TextileType? get type => _type;
  MaterialCondition? get condition => _condition;

  set type(TextileType? v) {
    _type = v;
    notifyListeners();
  }

  set condition(MaterialCondition? v) {
    _condition = v;
    notifyListeners();
  }

  static String? _nullIfEmpty(String s) => s.trim().isEmpty ? null : s.trim();

  MaterialCreate toCreate() => MaterialCreate(
        name: name.text.trim(),
        materialType: _type!,
        condition: _condition!,
        city: city.text.trim(),
        totalKg: normalizeDecimal(mass.text),
        composition: _nullIfEmpty(composition.text),
        scrapSize: _nullIfEmpty(scrapSize.text),
        pricePerKg: _nullIfEmpty(normalizeDecimal(price.text)),
      );

  /// Only fields that differ from [base]; cleared optional fields send null.
  Map<String, Object?> diff(MaterialItem base) {
    final f = <String, Object?>{};
    if (name.text.trim() != base.name) f['name'] = name.text.trim();
    if (_type != null && _type != base.materialType) {
      f['material_type'] = _type!.api;
    }
    if (_condition != null && _condition != base.condition) {
      f['condition'] = _condition!.api;
    }
    final cityText = _nullIfEmpty(city.text);
    if (cityText != base.city) f['city'] = cityText;
    final comp = _nullIfEmpty(composition.text);
    if (comp != base.composition) f['composition'] = comp;
    final scrap = _nullIfEmpty(scrapSize.text);
    if (scrap != base.scrapSize) f['scrap_size'] = scrap;
    final p = _nullIfEmpty(normalizeDecimal(price.text));
    if (canonDecimal(p, 2) != canonDecimal(base.pricePerKg, 2)) {
      f['price_per_kg'] = p;
    }
    final baseMass = base.balance?.totalKg;
    final m = normalizeDecimal(mass.text);
    if (m.isNotEmpty && canonDecimal(m, 3) != canonDecimal(baseMass, 3)) {
      f['total_kg'] = m;
    }
    return f;
  }

  @override
  void dispose() {
    name.dispose();
    mass.dispose();
    city.dispose();
    price.dispose();
    composition.dispose();
    scrapSize.dispose();
    super.dispose();
  }
}

/// Pads decimals so "12.5" and "12.500" compare equal (string compare only).
String? canonDecimal(String? s, int places) {
  if (s == null || s.isEmpty) return null;
  final parts = s.split('.');
  final whole = parts[0].replaceFirst(RegExp(r'^0+(?=\d)'), '');
  final frac = (parts.length > 1 ? parts[1] : '').padRight(places, '0');
  return '$whole.$frac';
}
