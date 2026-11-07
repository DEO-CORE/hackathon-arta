import '../../../core/format/mass_format.dart';
import '../../../core/network/api_exception.dart';

/// Status values of docs/api.md (reservation lifecycle). Unknown server values
/// map to [unknown] so a newer backend never crashes the client.
enum ReservationStatus {
  pending('pending', 'Ждёт ответа'),
  confirmed('confirmed', 'Резерв подтверждён'),
  transferred('transferred', 'Передано'),
  completed('completed', 'Получено'),
  cancelled('cancelled', 'Отменено'),
  unknown('unknown', 'Статус неизвестен');

  const ReservationStatus(this.api, this.label);
  final String api;
  final String label;

  static ReservationStatus parse(Object? v) => values
      .firstWhere((e) => e.api == v, orElse: () => ReservationStatus.unknown);

  /// Still in progress; used by the supplier's incoming-requests list.
  bool get isActive =>
      this == pending || this == confirmed || this == transferred;
}

/// PATCH /reservations/{id} actions.
enum ReservationAction {
  confirm('confirm'),
  cancel('cancel'),
  transfer('transfer'),
  complete('complete');

  const ReservationAction(this.api);
  final String api;
}

class _Json {
  _Json(Object? raw) : _m = raw is Map ? Map<String, dynamic>.from(raw) : null {
    if (_m == null) throw ApiException.invalidResponse();
  }
  final Map<String, dynamic>? _m;

  T req<T>(String key) {
    final v = _m![key];
    if (v is! T) throw ApiException.invalidResponse();
    return v;
  }

  T? opt<T>(String key) {
    final v = _m![key];
    if (v == null) return null;
    if (v is! T) throw ApiException.invalidResponse();
    return v;
  }

  /// Mass and money are decimal strings; a JSON number is a contract violation.
  String decimal(String key) {
    final v = req<String>(key);
    if (double.tryParse(v) == null) throw ApiException.invalidResponse();
    return v;
  }

  String? decimalOpt(String key) {
    final v = opt<String>(key);
    if (v != null && double.tryParse(v) == null) {
      throw ApiException.invalidResponse();
    }
    return v;
  }

  DateTime? dateOpt(String key) {
    final v = opt<String>(key);
    return v == null ? null : DateTime.tryParse(v)?.toUtc();
  }
}

/// Deal created by `transfer` (TransactionOut).
class DealTransaction {
  const DealTransaction({
    required this.id,
    required this.reservationId,
    required this.transferredKg,
    required this.confirmedReuseKg,
    this.saleAmountKgs,
    this.transferConfirmedAt,
    this.receiptConfirmedAt,
    this.materialId,
    this.materialName,
    this.createdAt,
  });

  /// Covers TransactionOut and the GET /transactions row, which may add
  /// `material_id` and `material_name` (docs/architecture/reservation-lifecycle.md).
  factory DealTransaction.fromJson(Object? raw) {
    final j = _Json(raw);
    return DealTransaction(
      id: j.req<String>('id'),
      reservationId: j.req<String>('reservation_id'),
      transferredKg: j.decimal('transferred_kg'),
      confirmedReuseKg: j.decimalOpt('confirmed_reuse_kg') ?? '0.000',
      saleAmountKgs: j.decimalOpt('sale_amount_kgs'),
      transferConfirmedAt: j.dateOpt('transfer_confirmed_at'),
      receiptConfirmedAt: j.dateOpt('receipt_confirmed_at'),
      materialId: j.opt<String>('material_id'),
      materialName: j.opt<String>('material_name'),
      createdAt: j.dateOpt('created_at'),
    );
  }

  final String id;
  final String reservationId;
  final String transferredKg;
  final String confirmedReuseKg;
  final String? saleAmountKgs;
  final DateTime? transferConfirmedAt;
  final DateTime? receiptConfirmedAt;
  final String? materialId;
  final String? materialName;
  final DateTime? createdAt;

  bool get isReceived => receiptConfirmedAt != null;
}

class Reservation {
  const Reservation({
    required this.id,
    required this.materialId,
    required this.materialName,
    required this.quantityKg,
    required this.status,
    this.buyerOrganizationName,
    this.sellerOrganizationName,
    this.agreedPricePerKg,
    this.cancelReason,
    this.cancelledByRole,
    this.transaction,
    this.contacts,
    this.createdAt,
  });

  factory Reservation.fromJson(Object? raw) {
    final j = _Json(raw);
    final tx = j.opt<Object>('transaction');
    return Reservation(
      id: j.req<String>('id'),
      materialId: j.req<String>('material_id'),
      materialName: j.req<String>('material_name'),
      quantityKg: j.decimal('quantity_kg'),
      status: ReservationStatus.parse(j.req<String>('status')),
      // Optional display names; absent until the backend adds them.
      buyerOrganizationName: j.opt<String>('buyer_organization_name'),
      sellerOrganizationName: j.opt<String>('seller_organization_name'),
      agreedPricePerKg: j.decimalOpt('agreed_price_per_kg'),
      cancelReason: j.opt<String>('cancel_reason'),
      cancelledByRole: j.opt<String>('cancelled_by_role'),
      transaction: tx == null ? null : DealTransaction.fromJson(tx),
      contacts: _contacts(j.opt<Object>('counterparty_contacts')),
      createdAt: j.dateOpt('created_at'),
    );
  }

  static Map<String, String>? _contacts(Object? raw) {
    if (raw is! Map) return null;
    return {
      for (final e in raw.entries)
        if (e.key is String && e.value is String)
          e.key as String: e.value as String
    };
  }

  final String id;
  final String materialId;
  final String materialName;
  final String quantityKg;
  final ReservationStatus status;
  final String? buyerOrganizationName;
  final String? sellerOrganizationName;
  final String? agreedPricePerKg;
  final String? cancelReason;
  final String? cancelledByRole;
  final DealTransaction? transaction;

  /// Counterparty contacts; the server fills them only for deal participants.
  final Map<String, String>? contacts;
  final DateTime? createdAt;

  /// Buyer organization as shown to the supplier. Falls back to the contact
  /// card name when the list has no dedicated field.
  String? get buyerName =>
      buyerOrganizationName ??
      contacts?['organization_name'] ??
      contacts?['name'];

  String? get sellerName =>
      sellerOrganizationName ??
      contacts?['organization_name'] ??
      contacts?['name'];
}

class ReservationPage {
  const ReservationPage(
      {required this.items, required this.page, required this.total});

  factory ReservationPage.fromJson(Object? raw) {
    final j = _Json(raw);
    return ReservationPage(
      items: j
          .req<List<dynamic>>('items')
          .map(Reservation.fromJson)
          .toList(growable: false),
      page: j.req<int>('page'),
      total: j.req<int>('total'),
    );
  }

  final List<Reservation> items;
  final int page;
  final int total;
}

class TransactionPage {
  const TransactionPage(
      {required this.items, required this.page, required this.total});

  factory TransactionPage.fromJson(Object? raw) {
    final j = _Json(raw);
    return TransactionPage(
      items: j
          .req<List<dynamic>>('items')
          .map(DealTransaction.fromJson)
          .toList(growable: false),
      page: j.req<int>('page'),
      total: j.req<int>('total'),
    );
  }

  final List<DealTransaction> items;
  final int page;
  final int total;
}

/// Request payload of POST /reservations. The key belongs to one user intent.
class ReservationRequest {
  const ReservationRequest({
    required this.materialId,
    required this.quantityKg,
    required this.idempotencyKey,
    this.agreedPricePerKg,
  });

  final String materialId;
  final String quantityKg;
  final String? agreedPricePerKg;
  final String idempotencyKey;

  Map<String, Object> toJson() => {
        'material_id': materialId,
        'quantity_kg': quantityKg,
        if (agreedPricePerKg != null) 'agreed_price_per_kg': agreedPricePerKg!,
      };
}

/// Positive decimal in kg, at most [maxKg], three fractional digits. Display
/// validation only; the server re-checks stock on every request.
String? validateRequestKg(String? raw, String maxKg) {
  final s = (raw ?? '').trim().replaceAll(',', '.');
  if (s.isEmpty) return 'Укажите массу';
  if (!RegExp(r'^\d+(\.\d{1,3})?$').hasMatch(s)) {
    return 'Введите число, не более 3 знаков после запятой';
  }
  final v = double.parse(s);
  if (v <= 0) return 'Масса должна быть больше нуля';
  final max = double.tryParse(maxKg);
  if (max != null && v > max) return 'Доступно не более ${formatKg(maxKg)}';
  return null;
}

/// Normalises user input ("12,5") to the API decimal string ("12.5").
String normalizeKg(String raw) => raw.trim().replaceAll(',', '.');
