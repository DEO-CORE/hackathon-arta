import '../../../core/network/api_exception.dart';

/// Wire statuses (ai-schema.md 11.3). Anything unknown is treated as failed.
enum AnalysisStatus {
  pending,
  running,
  succeeded,
  failed,
  interrupted,
  unknown;

  static AnalysisStatus parse(Object? v) => AnalysisStatus.values.firstWhere(
      (e) => e.name == v && e != AnalysisStatus.unknown,
      orElse: () => AnalysisStatus.unknown);

  bool get isActive =>
      this == AnalysisStatus.pending || this == AnalysisStatus.running;
  bool get isFailure =>
      this == AnalysisStatus.failed ||
      this == AnalysisStatus.interrupted ||
      this == AnalysisStatus.unknown;
}

/// Qualitative only; the schema has no numeric confidence and none is shown.
enum Level {
  high('высокая', 'Высокая'),
  medium('средняя', 'Средняя'),
  low('низкая', 'Низкая'),
  unknown('неизвестно', 'Неизвестно');

  const Level(this.confidenceWord, this.suitabilityWord);
  final String confidenceWord;
  final String suitabilityWord;

  static Level parse(Object? v) =>
      Level.values.firstWhere((e) => e.name == v, orElse: () => Level.unknown);
}

const reuseTypeLabels = <String, String>{
  'cleaning_rags': 'Протирочные ткани',
  'stuffing_filling': 'Наполнитель',
  'patchwork_crafts': 'Лоскутное шитьё и рукоделие',
  'accessories_small_goods': 'Аксессуары и мелкие изделия',
  'insulation_padding': 'Утеплитель и подкладка',
  'recycling_shredding': 'Переработка и измельчение',
  'other': 'Другое',
};

const colorLabels = <String, String>{
  'white': 'белый',
  'black': 'чёрный',
  'gray': 'серый',
  'beige': 'бежевый',
  'brown': 'коричневый',
  'red': 'красный',
  'orange': 'оранжевый',
  'yellow': 'жёлтый',
  'green': 'зелёный',
  'blue': 'синий',
  'purple': 'фиолетовый',
  'pink': 'розовый',
  'multicolor': 'разноцветный',
  'other': 'другой',
};

const patternLabels = <String, String>{
  'solid': 'однотонный',
  'striped': 'полоска',
  'checked': 'клетка',
  'floral': 'цветочный',
  'geometric': 'геометрический',
  'printed_other': 'принт',
  'mixed': 'смешанный',
  'other': 'другой',
};

const textureLabels = <String, String>{
  'smooth': 'гладкая',
  'ribbed': 'рубчик',
  'woven_looking': 'похожа на тканое полотно',
  'knit_looking': 'похожа на трикотаж',
  'fleecy': 'флис',
  'fuzzy': 'ворсистая',
  'glossy': 'глянцевая',
  'rough': 'грубая',
  'other': 'другая',
};

/// One visual feature: [value] is null when the model could not tell.
class VisualFeature {
  const VisualFeature({
    required this.value,
    required this.description,
    required this.confidence,
    this.secondary = const [],
  });

  final String? value;
  final String? description;
  final Level confidence;
  final List<String> secondary;

  bool get isUnknown => value == null && (description ?? '').isEmpty;
}

class ReuseOption {
  const ReuseOption({
    required this.reuseType,
    required this.suitability,
    required this.reason,
  });
  final String reuseType;
  final Level suitability;
  final String reason;

  String get label => reuseTypeLabels[reuseType] ?? 'Другое';
}

class AnalysisResult {
  const AnalysisResult({
    required this.color,
    required this.pattern,
    required this.texture,
    required this.reuseOptions,
    this.notes,
  });

  final VisualFeature color;
  final VisualFeature pattern;
  final VisualFeature texture;
  final List<ReuseOption> reuseOptions;
  final String? notes;
}

Map<String, dynamic> _map(Object? raw) {
  if (raw is! Map) throw ApiException.invalidResponse();
  return Map<String, dynamic>.from(raw);
}

String? _optString(Map<String, dynamic> m, String key, {int max = 600}) {
  final v = m[key];
  if (v == null) return null;
  if (v is! String || v.length > max) throw ApiException.invalidResponse();
  return v;
}

VisualFeature _feature(Object? raw, {required String valueKey}) {
  final m = _map(raw);
  final sec = m['secondary'];
  return VisualFeature(
    value: _optString(m, valueKey, max: 40),
    description: _optString(m, 'description'),
    confidence: Level.parse(m['confidence']),
    secondary: sec is List ? sec.whereType<String>().toList() : const [],
  );
}

/// Strict: one reuse option without a valid reason invalidates the whole
/// result, so no partial suggestions are ever shown (ai-schema.md 11.2).
AnalysisResult parseResult(Object? raw) {
  final m = _map(raw);
  final f = _map(m['visual_features']);
  final options = m['reuse_options'];
  if (options is! List || options.length > 5) {
    throw ApiException.invalidResponse();
  }
  return AnalysisResult(
    color: _feature(f['color'], valueKey: 'primary'),
    pattern: _feature(f['pattern'], valueKey: 'value'),
    texture: _feature(f['apparent_texture'], valueKey: 'value'),
    reuseOptions: [
      for (final o in options)
        () {
          final om = _map(o);
          final reason = om['reason'];
          final type = om['reuse_type'];
          if (reason is! String ||
              reason.trim().length < 10 ||
              reason.length > 300 ||
              type is! String) {
            throw ApiException.invalidResponse();
          }
          return ReuseOption(
            reuseType: type,
            suitability: Level.parse(om['suitability']),
            reason: reason,
          );
        }()
    ],
    notes: _optString(m, 'notes', max: 500),
  );
}

class Analysis {
  const Analysis({
    required this.id,
    required this.materialId,
    required this.status,
    required this.inputVersion,
    required this.isCurrent,
    this.mode,
    this.errorCode,
    this.result,
  });

  factory Analysis.fromJson(Object? raw) {
    final m = _map(raw);
    final id = m['id'];
    final materialId = m['material_id'];
    final version = m['input_version'];
    if (id is! String || materialId is! String || version is! int) {
      throw ApiException.invalidResponse();
    }
    final status = AnalysisStatus.parse(m['status']);
    return Analysis(
      id: id,
      materialId: materialId,
      status: status,
      inputVersion: version,
      isCurrent: m['is_current'] is bool ? m['is_current'] as bool : true,
      mode: m['mode'] is String ? m['mode'] as String : null,
      errorCode: m['error_code'] is String ? m['error_code'] as String : null,
      result: status == AnalysisStatus.succeeded && m['result'] != null
          ? parseResult(m['result'])
          : null,
    );
  }

  final String id;
  final String materialId;
  final AnalysisStatus status;
  final int inputVersion;
  final bool isCurrent;

  /// `live` for a real provider; anything else (mock, fallback, demo) is a
  /// simulation and is always labelled as such.
  final String? mode;
  final String? errorCode;
  final AnalysisResult? result;

  bool get isSimulation => mode != null && mode != 'live';
  bool get isFallback => mode == 'fallback';
}

class AnalysisStart {
  const AnalysisStart({required this.analysisId, required this.status});
  final String analysisId;
  final AnalysisStatus status;

  factory AnalysisStart.fromJson(Object? raw) {
    final m = _map(raw);
    final id = m['analysis_id'];
    if (id is! String) throw ApiException.invalidResponse();
    return AnalysisStart(
        analysisId: id, status: AnalysisStatus.parse(m['status']));
  }
}

/// Texts by `error_code` (ai-schema.md 11.6). Unknown code gets INTERNAL_ERROR.
const analysisErrorTexts = <String, String>{
  'PROVIDER_TIMEOUT':
      'Сервис анализа не ответил вовремя. Попробуйте ещё раз или заполните данные вручную.',
  'PROVIDER_UNAVAILABLE':
      'Сервис анализа временно недоступен. Вы можете продолжить вручную.',
  'PROVIDER_RATE_LIMITED': 'Сервис анализа перегружен. Повторите позже.',
  'PROVIDER_AUTH_ERROR':
      'Анализ сейчас не настроен. Заполните характеристики вручную.',
  'PROVIDER_REFUSED':
      'Сервис не смог проанализировать это фото. Заполните данные вручную или загрузите другое фото.',
  'INVALID_PROVIDER_RESPONSE':
      'Ответ анализа не прошёл проверку и не сохранён. Повторите или продолжите вручную.',
  'IMAGE_UNAVAILABLE':
      'Не удалось прочитать фото партии. Проверьте фото и повторите.',
  'INTERRUPTED': 'Анализ прерван. Запустите заново.',
  'INTERNAL_ERROR':
      'Не удалось выполнить анализ. Повторите позже или продолжите вручную.',
};

String analysisErrorText(String? code, AnalysisStatus status) {
  if (status == AnalysisStatus.interrupted) {
    return analysisErrorTexts['INTERRUPTED']!;
  }
  return analysisErrorTexts[code] ?? analysisErrorTexts['INTERNAL_ERROR']!;
}

/// Retrying does not help for these two codes (ai-schema.md 11.5).
bool analysisRetryAllowed(String? code) =>
    code != 'PROVIDER_AUTH_ERROR' && code != 'PROVIDER_REFUSED';
