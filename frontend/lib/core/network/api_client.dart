import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../config/app_config.dart';
import '../session/session.dart';
import 'api_exception.dart';

/// Dio wrapper: Bearer token, base URL from config, envelope mapping.
class ApiClient {
  ApiClient({
    required String baseUrl,
    required String? Function() tokenReader,
    required void Function() onUnauthorized,
    Dio? dio,
  }) : dio = dio ?? Dio() {
    this.dio.options = BaseOptions(
      baseUrl: baseUrl,
      connectTimeout: const Duration(seconds: 15),
      receiveTimeout: const Duration(seconds: 30),
      contentType: Headers.jsonContentType,
      responseType: ResponseType.json,
    );
    this.dio.interceptors.add(
          InterceptorsWrapper(
            onRequest: (options, handler) {
              if (baseUrl.isEmpty) {
                return handler.reject(
                  DioException(
                    requestOptions: options,
                    error: ApiException.config(),
                  ),
                );
              }
              final token = tokenReader();
              if (token != null && token.isNotEmpty) {
                options.headers['Authorization'] = 'Bearer $token';
              }
              handler.next(options);
            },
            onError: (e, handler) {
              final mapped = ApiException.fromDio(e);
              // Login failures are INVALID_CREDENTIALS and must not end a session.
              if (mapped.statusCode == 401 && mapped.isUnauthenticated) {
                onUnauthorized();
              }
              handler.reject(
                DioException(
                  requestOptions: e.requestOptions,
                  response: e.response,
                  type: e.type,
                  error: mapped,
                ),
              );
            },
          ),
        );
  }

  final Dio dio;
}

/// Runs a Dio call and rethrows failures as [ApiException].
Future<T> apiCall<T>(Future<T> Function() call) async {
  try {
    return await call();
  } on DioException catch (e) {
    throw ApiException.fromDio(e);
  }
}

final apiClientProvider = Provider<ApiClient>((ref) {
  final client = ApiClient(
    baseUrl: ref.watch(appConfigProvider).apiBaseUrl,
    tokenReader: () => ref.read(sessionProvider).token,
    onUnauthorized: () => ref.read(sessionProvider.notifier).expire(),
  );
  ref.onDispose(() => client.dio.close());
  return client;
});
