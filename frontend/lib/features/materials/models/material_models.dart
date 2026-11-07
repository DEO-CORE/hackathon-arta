import '../../../core/network/api_exception.dart';
import 'material_enums.dart';

/// Strict readers: a malformed server payload becomes an
/// [ApiException.invalidResponse] instead of a half-filled object.
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

  /// Mass and money arrive as decimal strings; a JSON number is a contract violation.
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

/// Mass balance of an own material. All values are decimal strings in kg.
class MassBalance {
  const MassBalance({
    required this.totalKg,
    required this.availableKg,
    required this.heldKg,
    required this.transferredKg,
    required this.internallyUsedKg,
  });

  factory MassBalance.fromJson(Object? raw) {
    final j = _Json(raw);
    return MassBalance(
      totalKg: j.decimal('total_kg'),
      availableKg: j.decimal('available_kg'),
      heldKg: j.decimal('held_kg'),
      transferredKg: j.decimal('transferred_kg'),
      internallyUsedKg: j.decimal('internally_used_kg'),
    );
  }

  final String totalKg;
  final String availableKg;
  final String heldKg;
  final String transferredKg;
  final String internallyUsedKg;
}

/// Image metadata only; the file is reached through a short-lived signed URL.
class MaterialImage {
  const MaterialImage({
    required this.id,
    required this.mimeType,
    required this.sizeBytes,
    required this.sortOrder,
  });

  factory MaterialImage.fromJson(Object? raw) {
    final j = _Json(raw);
    return MaterialImage(
      id: j.req<String>('id'),
      mimeType: j.req<String>('mime_type'),
      sizeBytes: j.req<int>('size_bytes'),
      sortOrder: j.req<int>('sort_order'),
    );
  }

  final String id;
  final String mimeType;
  final int sizeBytes;
  final int sortOrder;
}

/// Covers both `MaterialOut` (owner) and `MaterialPublicOut` (buyer).
/// [balance] is non-null only in the owner view.
class MaterialItem {
  const MaterialItem({
    required this.id,
    required this.name,
    required this.status,
    required this.version,
    required this.availableKg,
    required this.images,
    this.materialType,
    this.composition,
    this.scrapSize,
    this.condition,
    this.pricePerKg,
    this.city,
    this.balance,
    this.confirmedAt,
    this.isConfirmationCurrent = false,
    this.organizationName,
  });

  factory MaterialItem.fromJson(Object? raw) {
    final j = _Json(raw);
    final balanceRaw = j.opt<Object>('balance');
    final balance =
        balanceRaw == null ? null : MassBalance.fromJson(balanceRaw);
    final available = balance?.availableKg ?? j.decimal('available_kg');
    final images = j.opt<List<dynamic>>('images') ?? const [];
    return MaterialItem(
      id: j.req<String>('id'),
      name: j.req<String>('name'),
      status: MaterialStatus.parse(j.req<String>('status')),
      version: j.req<int>('version'),
      availableKg: available,
      balance: balance,
      materialType: TextileType.parse(j.opt<String>('material_type')),
      composition: j.opt<String>('composition'),
      scrapSize: j.opt<String>('scrap_size'),
      condition: MaterialCondition.parse(j.opt<String>('condition')),
      pricePerKg: j.decimalOpt('price_per_kg'),
      city: j.opt<String>('city'),
      confirmedAt: j.dateOpt('confirmed_at'),
      isConfirmationCurrent: j.opt<bool>('is_confirmation_current') ?? false,
      organizationName: j.opt<String>('organization_name'),
      images: images.map(MaterialImage.fromJson).toList(growable: false),
    );
  }

  final String id;
  final String name;
  final MaterialStatus status;
  final int version;
  final String availableKg;
  final MassBalance? balance;
  final TextileType? materialType;
  final String? composition;
  final String? scrapSize;
  final MaterialCondition? condition;
  final String? pricePerKg;
  final String? city;
  final DateTime? confirmedAt;
  final bool isConfirmationCurrent;
  final String? organizationName;
  final List<MaterialImage> images;

  bool get isOwnerView => balance != null;

  /// Only used by the synthetic demo repository to model server transitions.
  MaterialItem copyWith({
    MaterialStatus? status,
    int? version,
    DateTime? confirmedAt,
    bool clearConfirmedAt = false,
    bool? isConfirmationCurrent,
    List<MaterialImage>? images,
  }) =>
      MaterialItem(
        id: id,
        name: name,
        status: status ?? this.status,
        version: version ?? this.version,
        availableKg: availableKg,
        images: images ?? this.images,
        materialType: materialType,
        composition: composition,
        scrapSize: scrapSize,
        condition: condition,
        pricePerKg: pricePerKg,
        city: city,
        balance: balance,
        confirmedAt:
            clearConfirmedAt ? null : (confirmedAt ?? this.confirmedAt),
        isConfirmationCurrent:
            isConfirmationCurrent ?? this.isConfirmationCurrent,
        organizationName: organizationName,
      );
}

class MaterialListPage {
  const MaterialListPage({
    required this.items,
    required this.page,
    required this.pageSize,
    required this.total,
  });

  factory MaterialListPage.fromJson(Object? raw) {
    final j = _Json(raw);
    return MaterialListPage(
      items: j
          .req<List<dynamic>>('items')
          .map(MaterialItem.fromJson)
          .toList(growable: false),
      page: j.req<int>('page'),
      pageSize: j.req<int>('page_size'),
      total: j.req<int>('total'),
    );
  }

  final List<MaterialItem> items;
  final int page;
  final int pageSize;
  final int total;
}

class ImageUploadResult {
  const ImageUploadResult({required this.image, required this.materialVersion});

  factory ImageUploadResult.fromJson(Object? raw) {
    final j = _Json(raw);
    return ImageUploadResult(
      image: MaterialImage.fromJson(j.req<Object>('image')),
      materialVersion: j.req<int>('material_version'),
    );
  }

  final MaterialImage image;
  final int materialVersion;
}

class SignedUrl {
  const SignedUrl({required this.url, required this.expiresAt});

  factory SignedUrl.fromJson(Object? raw) {
    final j = _Json(raw);
    return SignedUrl(
      url: j.req<String>('url'),
      expiresAt: j.dateOpt('expires_at'),
    );
  }

  final String url;
  final DateTime? expiresAt;
}
