import 'material_enums.dart';

/// Buyer catalog search and filters. Sent to GET /materials as query
/// parameters; the server does the matching, the client never filters.
const defaultCatalogSort = 'created_at_desc';
const catalogSorts = {
  'created_at_desc': 'Сначала новые',
  'available_kg_desc': 'Масса: больше сначала',
};

class CatalogFilter {
  const CatalogFilter({
    this.q = '',
    this.type,
    this.condition,
    this.city = '',
    this.minAvailableKg = '',
    this.sort = defaultCatalogSort,
  });

  final String q;
  final TextileType? type;
  final MaterialCondition? condition;
  final String city;

  /// Decimal string as typed by the user (dot or comma); empty means no limit.
  final String minAvailableKg;

  /// Server sort value: `created_at_desc` or `available_kg_desc`.
  final String sort;

  bool get isEmpty =>
      q.trim().isEmpty &&
      type == null &&
      condition == null &&
      city.trim().isEmpty &&
      minAvailableKg.trim().isEmpty &&
      sort == defaultCatalogSort;

  /// Number of active filters, search text excluded.
  int get activeCount => [
        type != null,
        condition != null,
        city.trim().isNotEmpty,
        minAvailableKg.trim().isNotEmpty,
        sort != defaultCatalogSort,
      ].where((e) => e).length;

  CatalogFilter copyWith({
    String? q,
    TextileType? type,
    bool clearType = false,
    MaterialCondition? condition,
    bool clearCondition = false,
    String? city,
    String? minAvailableKg,
    String? sort,
  }) =>
      CatalogFilter(
        q: q ?? this.q,
        type: clearType ? null : (type ?? this.type),
        condition: clearCondition ? null : (condition ?? this.condition),
        city: city ?? this.city,
        minAvailableKg: minAvailableKg ?? this.minAvailableKg,
        sort: sort ?? this.sort,
      );

  Map<String, Object> toQuery() => {
        if (q.trim().isNotEmpty) 'q': q.trim(),
        if (type != null) 'material_type': [type!.api],
        if (condition != null) 'condition': [condition!.api],
        if (city.trim().isNotEmpty) 'city': city.trim(),
        if (minAvailableKg.trim().isNotEmpty)
          'min_available_kg': minAvailableKg.trim().replaceAll(',', '.'),
        if (sort != defaultCatalogSort) 'sort': sort,
      };

  @override
  bool operator ==(Object other) =>
      other is CatalogFilter &&
      other.q == q &&
      other.type == type &&
      other.condition == condition &&
      other.city == city &&
      other.minAvailableKg == minAvailableKg &&
      other.sort == sort;

  @override
  int get hashCode =>
      Object.hash(q, type, condition, city, minAvailableKg, sort);
}

/// Empty or a positive decimal with up to three fractional digits.
String? validateMinKg(String? v) {
  final s = (v ?? '').trim().replaceAll(',', '.');
  if (s.isEmpty) return null;
  if (!RegExp(r'^\d+(\.\d{1,3})?$').hasMatch(s)) {
    return 'Введите число, не более 3 знаков после запятой';
  }
  return null;
}
