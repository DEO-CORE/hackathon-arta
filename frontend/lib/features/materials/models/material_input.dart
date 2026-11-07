import 'material_enums.dart';

/// `MaterialCreateIn`. Mass and money stay decimal strings.
class MaterialCreate {
  const MaterialCreate({
    required this.name,
    required this.materialType,
    required this.condition,
    required this.city,
    required this.totalKg,
    this.composition,
    this.scrapSize,
    this.pricePerKg,
  });

  final String name;
  final TextileType materialType;
  final MaterialCondition condition;
  final String city;
  final String totalKg;
  final String? composition;
  final String? scrapSize;
  final String? pricePerKg;

  Map<String, Object?> toJson() => {
        'name': name,
        'material_type': materialType.api,
        'condition': condition.api,
        'city': city,
        'total_kg': totalKg,
        if (composition != null) 'composition': composition,
        if (scrapSize != null) 'scrap_size': scrapSize,
        if (pricePerKg != null) 'price_per_kg': pricePerKg,
      };
}

/// `MaterialPatchIn`: `version` plus only the fields that changed.
/// An explicit null value clears an optional field on the server.
class MaterialPatch {
  const MaterialPatch({required this.version, required this.fields});

  final int version;
  final Map<String, Object?> fields;

  bool get isEmpty => fields.isEmpty;

  Map<String, Object?> toJson() => {'version': version, ...fields};
}
