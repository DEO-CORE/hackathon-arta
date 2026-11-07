import 'package:dio/dio.dart';

import '../../../core/network/api_client.dart';
import '../../../core/network/api_exception.dart';
import '../models/reservation_models.dart';

abstract class ReservationRepository {
  /// GET /reservations for the caller's own side (server decides which).
  Future<ReservationPage> list({
    List<ReservationStatus>? statuses,
    int page = 1,
    int pageSize = 20,
  });

  /// POST /reservations. A retry must pass the same [ReservationRequest.idempotencyKey].
  Future<Reservation> create(ReservationRequest request);

  /// PATCH /reservations/{id}. [idempotencyKey] is optional on this route.
  Future<Reservation> act(
    String id,
    ReservationAction action, {
    String? reason,
    String? transferredKg,
    String? idempotencyKey,
  });

  /// GET /transactions (paged history of the caller's side).
  Future<TransactionPage> transactions({int page = 1, int pageSize = 20});
}

class ApiReservationRepository implements ReservationRepository {
  ApiReservationRepository(this._client);
  final ApiClient _client;

  @override
  Future<ReservationPage> list({
    List<ReservationStatus>? statuses,
    int page = 1,
    int pageSize = 20,
  }) =>
      apiCall(() async {
        final r = await _client.dio.get<Object>(
          '/reservations',
          queryParameters: {
            'page': page,
            'page_size': pageSize,
            if (statuses != null && statuses.isNotEmpty)
              'status': [for (final s in statuses) s.api],
          },
          // Repeated keys (status=a&status=b) as FastAPI expects for a list.
          options: Options(listFormat: ListFormat.multi),
        );
        return ReservationPage.fromJson(r.data);
      });

  @override
  Future<Reservation> create(ReservationRequest request) => apiCall(() async {
        final r = await _client.dio.post<Object>(
          '/reservations',
          data: request.toJson(),
          options:
              Options(headers: {'Idempotency-Key': request.idempotencyKey}),
        );
        return Reservation.fromJson(r.data);
      });

  @override
  Future<Reservation> act(
    String id,
    ReservationAction action, {
    String? reason,
    String? transferredKg,
    String? idempotencyKey,
  }) =>
      apiCall(() async {
        final r = await _client.dio.patch<Object>(
          '/reservations/$id',
          data: {
            'action': action.api,
            if (reason != null) 'reason': reason,
            if (transferredKg != null) 'transferred_kg': transferredKg,
          },
          options: idempotencyKey == null
              ? null
              : Options(headers: {'Idempotency-Key': idempotencyKey}),
        );
        return Reservation.fromJson(r.data);
      });

  @override
  Future<TransactionPage> transactions({int page = 1, int pageSize = 20}) =>
      apiCall(() async {
        final r = await _client.dio.get<Object>(
          '/transactions',
          queryParameters: {'page': page, 'page_size': pageSize},
        );
        return TransactionPage.fromJson(r.data);
      });
}

/// USE_DEMO_DATA only: the demo has no reservations. Lists are empty and
/// actions are refused with an honest message; nothing is faked.
class DemoReservationRepository implements ReservationRepository {
  static const _unsupported = ApiException(
    code: 'DEMO_UNSUPPORTED',
    message: 'В демо-режиме заявки недоступны. Подключите сервер.',
  );

  @override
  Future<ReservationPage> list({
    List<ReservationStatus>? statuses,
    int page = 1,
    int pageSize = 20,
  }) async =>
      const ReservationPage(items: [], page: 1, total: 0);

  @override
  Future<Reservation> create(ReservationRequest request) async =>
      throw _unsupported;

  @override
  Future<Reservation> act(String id, ReservationAction action,
          {String? reason,
          String? transferredKg,
          String? idempotencyKey}) async =>
      throw _unsupported;

  @override
  Future<TransactionPage> transactions(
          {int page = 1, int pageSize = 20}) async =>
      const TransactionPage(items: [], page: 1, total: 0);
}
