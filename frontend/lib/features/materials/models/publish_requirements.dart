import '../../../core/network/api_exception.dart';
import 'material_models.dart';

/// Server field names (api.md 18.8 `details.missing`) in checklist order.
const _publishLabels = <String, String>{
  'material_type': 'Укажите тип материала',
  'total_kg': 'Укажите массу больше нуля',
  'condition': 'Укажите состояние',
  'city': 'Укажите город',
  'images': 'Добавьте хотя бы одно фото',
  'confirmation': 'Подтвердите характеристики',
};

bool _isPositive(String? kg) {
  final v = double.tryParse(kg ?? '');
  return v != null && v > 0;
}

/// Pre-check mirroring the server publish rules, used only to explain what is
/// still missing. The server stays the authority and re-validates on publish.
List<String> missingPublishFields(MaterialItem m) => [
      if (m.materialType == null) 'material_type',
      if (!_isPositive(m.balance?.totalKg)) 'total_kg',
      if (m.condition == null) 'condition',
      if ((m.city ?? '').trim().isEmpty) 'city',
      if (m.images.isEmpty) 'images',
      if (!m.isConfirmationCurrent) 'confirmation',
    ];

/// Human labels; unknown server field names get a generic line, never a raw key.
List<String> publishMissingLabels(Iterable<String> fields) => [
      for (final f in fields)
        _publishLabels[f] ?? 'Не выполнено одно из требований публикации',
    ];

/// `details.missing` of PUBLISH_REQUIREMENTS_NOT_MET, or empty.
List<String> missingFromError(ApiException e) {
  final raw = e.details?['missing'];
  return raw is List ? raw.whereType<String>().toList() : const [];
}

const _publishShort = <String, String>{
  'material_type': 'тип',
  'total_kg': 'масса',
  'condition': 'состояние',
  'city': 'город',
  'images': 'фото',
  'confirmation': 'подтверждение',
};

/// Short lower-case names for a one-line "what is left" summary.
List<String> publishMissingShort(Iterable<String> fields) =>
    [for (final f in fields) _publishShort[f] ?? 'требование'];
