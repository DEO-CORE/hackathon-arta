/// Enums mirror docs/api.md section 2. Unknown server values map to `unknown`
/// so a newer backend never crashes the client.
enum MaterialStatus {
  draft('draft', 'Черновик'),
  available('available', 'Доступно'),
  reserved('reserved', 'Зарезервировано'),
  partiallyAllocated('partially_allocated', 'Частично распределено'),
  completed('completed', 'Завершено'),
  archived('archived', 'В архиве'),
  unknown('unknown', 'Статус неизвестен');

  const MaterialStatus(this.api, this.label);
  final String api;
  final String label;

  static MaterialStatus parse(Object? v) => MaterialStatus.values
      .firstWhere((e) => e.api == v, orElse: () => MaterialStatus.unknown);
}

enum TextileType {
  cotton('cotton', 'Хлопок'),
  wool('wool', 'Шерсть'),
  linen('linen', 'Лён'),
  silk('silk', 'Шёлк'),
  synthetic('synthetic', 'Синтетика'),
  knit('knit', 'Трикотаж'),
  denim('denim', 'Деним'),
  mixed('mixed', 'Смесовая ткань'),
  other('other', 'Другое'),
  unknown('unknown', 'Неизвестно');

  const TextileType(this.api, this.label);
  final String api;
  final String label;

  /// Values the user may choose in a form (excludes the fallback).
  static List<TextileType> get selectable =>
      values.where((e) => e != unknown).toList();

  static TextileType? parse(Object? v) => v == null
      ? null
      : TextileType.values
          .firstWhere((e) => e.api == v, orElse: () => TextileType.unknown);
}

enum MaterialCondition {
  unused('unused', 'Новое, не использовалось'),
  good('good', 'Хорошее'),
  worn('worn', 'Б/у, следы износа'),
  damaged('damaged', 'Повреждённое'),
  unknown('unknown', 'Неизвестно');

  const MaterialCondition(this.api, this.label);
  final String api;
  final String label;

  static List<MaterialCondition> get selectable =>
      values.where((e) => e != unknown).toList();

  static MaterialCondition? parse(Object? v) => v == null
      ? null
      : MaterialCondition.values.firstWhere((e) => e.api == v,
          orElse: () => MaterialCondition.unknown);
}
