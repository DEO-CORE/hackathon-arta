import '../../../core/network/api_exception.dart';
import 'publish_requirements.dart';

/// Russian text for publish / archive / confirm failures. Raw codes are never shown.
String lifecycleErrorText(ApiException e) {
  switch (e.code) {
    case 'VERSION_CONFLICT':
      return 'Данные партии изменились.';
    case 'ACTIVE_OBLIGATIONS':
      final held = e.details?['held_kg'];
      if (held is String) {
        return 'Нельзя архивировать: есть подтверждённые резервы ($held кг). Сначала отмените их.';
      }
      return 'Действие невозможно: по партии есть активные заявки или переданная масса.';
    case 'INVALID_TRANSITION':
      return 'Действие недоступно для текущего статуса';
    case 'PRECONDITION_FAILED':
      return 'Условия действия не выполнены. Обновите данные партии.';
    case 'PUBLISH_REQUIREMENTS_NOT_MET':
      final labels = publishMissingLabels(missingFromError(e));
      return labels.isEmpty
          ? 'Не выполнены требования публикации.'
          : 'Не выполнены требования публикации: ${labels.join('; ')}.';
  }
  final status = e.statusCode;
  if (status == 403) return 'Нет доступа к этой партии';
  if (status == 404) return 'Партия не найдена или недоступна';
  if (status == 429) {
    final s = e.retryAfterSeconds;
    return s == null
        ? 'Слишком много запросов, попробуйте позже'
        : 'Слишком много запросов, попробуйте через $s сек';
  }
  if (status != null && status >= 500) {
    return 'Ошибка сервера. Повторите попытку.';
  }
  return e.message;
}

/// Same exception with the localized message, so shared widgets can show it.
ApiException localizedLifecycleError(ApiException e) => ApiException(
      code: e.code,
      message: lifecycleErrorText(e),
      statusCode: e.statusCode,
      details: e.details,
      requestId: e.requestId,
      retryAfter: e.retryAfter,
    );

bool isRetryableServerError(ApiException e) =>
    (e.statusCode ?? 0) >= 500 || e.code == 'NETWORK_ERROR';
