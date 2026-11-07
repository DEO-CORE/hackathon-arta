import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/config/app_config.dart';
import '../../../core/network/api_client.dart';
import '../../../core/network/api_exception.dart';
import '../../../demo/demo_store.dart' show randomHex;
import '../data/reservation_repository.dart';
import '../models/reservation_models.dart';

final reservationRepositoryProvider = Provider<ReservationRepository>((ref) {
  // Demo data only by the explicit flag, never as an error fallback.
  if (ref.watch(appConfigProvider).useDemoData) {
    return DemoReservationRepository();
  }
  return ApiReservationRepository(ref.watch(apiClientProvider));
});

ApiException _asApi(Object e) => e is ApiException ? e : ApiException.network();

/// A server `details.missing` list is shown as a generic Russian line: field
/// names from the server are never put on screen.
ApiException friendlyError(ApiException e) {
  final missing = e.details?['missing'];
  if (missing is! List || missing.isEmpty) return e;
  return ApiException(
    code: e.code,
    message: '${e.message}\nНе заполнены обязательные поля.',
    statusCode: e.statusCode,
    details: e.details,
    requestId: e.requestId,
    retryAfter: e.retryAfter,
  );
}

// ------------------------------------------------------------------ lists

enum ReservationSegment {
  active([
    ReservationStatus.pending,
    ReservationStatus.confirmed,
    ReservationStatus.transferred,
  ]),
  history([ReservationStatus.completed, ReservationStatus.cancelled]);

  const ReservationSegment(this.statuses);
  final List<ReservationStatus> statuses;
}

const reservationPageSize = 20;

class ReservationListState {
  const ReservationListState({
    this.items = const [],
    this.total = 0,
    this.page = 0,
    this.loading = true,
    this.loadingMore = false,
    this.error,
    this.loadMoreError,
  });

  final List<Reservation> items;
  final int total;
  final int page;
  final bool loading;
  final bool loadingMore;
  final ApiException? error;
  final ApiException? loadMoreError;

  bool get hasMore => items.length < total;
}

class ReservationListController extends AutoDisposeFamilyNotifier<
    ReservationListState, ReservationSegment> {
  int _generation = 0;

  @override
  ReservationListState build(ReservationSegment arg) {
    Future.microtask(reload);
    return const ReservationListState();
  }

  Future<void> reload() async {
    final gen = ++_generation;
    state = const ReservationListState();
    try {
      final p = await ref
          .read(reservationRepositoryProvider)
          .list(statuses: arg.statuses, page: 1, pageSize: reservationPageSize);
      if (gen != _generation) return;
      state = ReservationListState(
          items: p.items, total: p.total, page: p.page, loading: false);
    } catch (e) {
      if (gen != _generation) return;
      state = ReservationListState(loading: false, error: _asApi(e));
    }
  }

  Future<void> loadMore() async {
    final s = state;
    if (s.loading || s.loadingMore || !s.hasMore) return;
    final gen = _generation;
    state = ReservationListState(
        items: s.items,
        total: s.total,
        page: s.page,
        loading: false,
        loadingMore: true);
    try {
      final p = await ref.read(reservationRepositoryProvider).list(
          statuses: arg.statuses,
          page: s.page + 1,
          pageSize: reservationPageSize);
      if (gen != _generation) return;
      state = ReservationListState(
          items: [...s.items, ...p.items],
          total: p.total,
          page: p.page,
          loading: false);
    } catch (e) {
      if (gen != _generation) return;
      state = ReservationListState(
          items: s.items,
          total: s.total,
          page: s.page,
          loading: false,
          loadMoreError: _asApi(e));
    }
  }
}

final reservationListProvider = AutoDisposeNotifierProviderFamily<
    ReservationListController,
    ReservationListState,
    ReservationSegment>(ReservationListController.new);

// ---------------------------------------------------------------- actions

class ReservationActionState {
  const ReservationActionState({this.busyId, this.error, this.doneMessage});
  final String? busyId;
  final ApiException? error;
  final String? doneMessage;
  bool get busy => busyId != null;
}

/// Runs PATCH actions one at a time. State changes only from server answers;
/// after success both lists are reloaded.
class ReservationActionController
    extends AutoDisposeNotifier<ReservationActionState> {
  @override
  ReservationActionState build() => const ReservationActionState();

  void clear() => state = const ReservationActionState();

  Future<bool> run(
    Reservation r,
    ReservationAction action, {
    String? reason,
    String? transferredKg,
    required String doneMessage,
  }) async {
    if (state.busy) return false;
    state = ReservationActionState(busyId: r.id);
    try {
      await ref
          .read(reservationRepositoryProvider)
          .act(r.id, action, reason: reason, transferredKg: transferredKg);
      state = ReservationActionState(doneMessage: doneMessage);
      for (final s in ReservationSegment.values) {
        ref.invalidate(reservationListProvider(s));
      }
      return true;
    } catch (e) {
      state = ReservationActionState(error: friendlyError(_asApi(e)));
      // A conflict means the data is stale: refresh so the card shows the truth.
      if (_asApi(e).statusCode == 409) {
        for (final s in ReservationSegment.values) {
          ref.invalidate(reservationListProvider(s));
        }
      }
      return false;
    }
  }
}

final reservationActionProvider = AutoDisposeNotifierProvider<
    ReservationActionController,
    ReservationActionState>(ReservationActionController.new);

// ------------------------------------------------------- reservation request

class ReserveState {
  const ReserveState({this.busy = false, this.error, this.created});
  final bool busy;
  final ApiException? error;
  final Reservation? created;
}

/// One controller per material. The idempotency key belongs to one user
/// intent (material + quantity + price): a retry after an error reuses it, a
/// changed quantity starts a new intent, success clears it.
class ReserveController
    extends AutoDisposeFamilyNotifier<ReserveState, String> {
  String? _signature;
  String? _key;

  /// Visible for tests.
  String? get currentKey => _key;

  @override
  ReserveState build(String arg) => const ReserveState();

  void clearError() => state = const ReserveState();

  Future<bool> submit({required String quantityKg, String? price}) async {
    if (state.busy) return false;
    final qty = normalizeKg(quantityKg);
    final signature = '$arg|$qty|${price ?? ''}';
    if (signature != _signature || _key == null) {
      _signature = signature;
      _key = 'res-${randomHex(16)}';
    }
    final request = ReservationRequest(
      materialId: arg,
      quantityKg: qty,
      agreedPricePerKg: price,
      idempotencyKey: _key!,
    );
    state = const ReserveState(busy: true);
    try {
      final r = await ref.read(reservationRepositoryProvider).create(request);
      _signature = null;
      _key = null;
      state = ReserveState(created: r);
      ref.invalidate(reservationListProvider(ReservationSegment.active));
      return true;
    } catch (e) {
      state = ReserveState(error: friendlyError(_asApi(e)));
      return false;
    }
  }
}

final reserveProvider =
    AutoDisposeNotifierProviderFamily<ReserveController, ReserveState, String>(
        ReserveController.new);
