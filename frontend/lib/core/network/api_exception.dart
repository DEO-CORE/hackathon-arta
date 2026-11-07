import 'package:dio/dio.dart';

/// Typed form of the standard error envelope (`error.code/message/details/request_id`).
class ApiException implements Exception {
  const ApiException({
    required this.code,
    required this.message,
    this.statusCode,
    this.details,
    this.requestId,
    this.retryAfter,
  });

  final String code;
  final String message;
  final int? statusCode;
  final Map<String, dynamic>? details;
  final String? requestId;

  /// Seconds from the `Retry-After` header, when the server sent one.
  final int? retryAfter;

  /// Body value (api.md 18.9) wins over the header.
  int? get retryAfterSeconds {
    final v = details?['retry_after_seconds'];
    return v is int && v > 0 ? v : retryAfter;
  }

  static const networkMessage =
      'Не удалось выполнить запрос. Проверьте соединение и повторите.';

  factory ApiException.network() =>
      const ApiException(code: 'NETWORK_ERROR', message: networkMessage);

  factory ApiException.config() => const ApiException(
        code: 'CONFIG_ERROR',
        message: 'Адрес сервера не задан. Соберите приложение с API_BASE_URL.',
      );

  factory ApiException.invalidResponse() => const ApiException(
        code: 'INVALID_RESPONSE',
        message: 'Сервер вернул неожиданный ответ. Повторите позже.',
      );

  /// Field-level messages from a 422 envelope: field -> message.
  Map<String, String> get fieldErrors {
    final errors = details?['errors'];
    if (errors is! List) return const {};
    final result = <String, String>{};
    for (final e in errors) {
      if (e is Map && e['field'] is String && e['message'] is String) {
        result[e['field'] as String] = e['message'] as String;
      }
    }
    return result;
  }

  bool get isUnauthenticated => code == 'UNAUTHENTICATED';

  /// Never exposes stack traces or raw bodies; unknown shapes get a safe text.
  factory ApiException.fromDio(DioException e) {
    if (e.error is ApiException) return e.error as ApiException;
    final response = e.response;
    final data = response?.data;
    if (data is Map && data['error'] is Map) {
      final err = Map<String, dynamic>.from(data['error'] as Map);
      final details = err['details'];
      return ApiException(
        code: err['code'] is String ? err['code'] as String : 'UNKNOWN',
        message: err['message'] is String
            ? err['message'] as String
            : 'Что-то пошло не так. Повторите позже.',
        statusCode: response?.statusCode,
        details: details is Map ? Map<String, dynamic>.from(details) : null,
        requestId: err['request_id'] is String
            ? err['request_id'] as String
            : response?.headers.value('x-request-id'),
        retryAfter: int.tryParse(response?.headers.value('retry-after') ?? ''),
      );
    }
    if (response != null) {
      return ApiException(
        code: 'UNKNOWN',
        message: 'Что-то пошло не так. Повторите позже.',
        statusCode: response.statusCode,
        requestId: response.headers.value('x-request-id'),
        retryAfter: int.tryParse(response.headers.value('retry-after') ?? ''),
      );
    }
    return ApiException.network();
  }

  @override
  String toString() => 'ApiException($code, $statusCode)';
}
