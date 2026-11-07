// SYNTHETIC DEMO DATA. Used only when built with --dart-define=USE_DEMO_DATA=true.
// No real organizations, contacts or photos; the UI shows a "Демо" banner.
import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import '../core/network/api_exception.dart';
import '../features/materials/data/material_repository.dart';
import '../features/materials/models/catalog_filter.dart';
import '../features/materials/models/material_enums.dart';
import '../features/materials/models/material_input.dart';
import '../features/materials/models/material_models.dart';
import '../features/materials/models/material_rules.dart';
import '../features/materials/models/publish_requirements.dart';
import 'demo_store.dart';

/// Implemented by the demo repository only; lets the profile screen reset it.
abstract class DemoResettable {
  Future<void> resetDemoData();
}

const _maxDemoPhotos = 5;

String _extensionOf(Uint8List b) {
  if (b.length > 3 && b[0] == 0x89) return 'png';
  if (b.length > 3 && b[0] == 0x52) return 'webp';
  return 'jpg';
}

String _mimeOf(String ext) => switch (ext) {
      'png' => 'image/png',
      'webp' => 'image/webp',
      _ => 'image/jpeg',
    };

/// Demo repository with the same rules as the API for versions, confirmation,
/// publish and archive. State survives restarts through [DemoStore].
class DemoMaterialRepository implements MaterialRepository, DemoResettable {
  DemoMaterialRepository({DemoStore? store, this.publicView = false})
      : _store = store ?? MemoryDemoStore();

  /// Buyer accounts: only published batches, without the owner's balance.
  final bool publicView;

  static bool _published(MaterialItem m) =>
      m.status == MaterialStatus.available ||
      m.status == MaterialStatus.partiallyAllocated;

  MaterialItem _viewOf(MaterialItem m) => !publicView
      ? m
      : MaterialItem(
          id: m.id,
          name: m.name,
          status: m.status,
          version: m.version,
          availableKg: m.availableKg,
          images: m.images,
          materialType: m.materialType,
          composition: m.composition,
          scrapSize: m.scrapSize,
          condition: m.condition,
          pricePerKg: m.pricePerKg,
          city: m.city,
          organizationName: 'Демо швейная фабрика',
        );

  final DemoStore _store;
  final List<MaterialItem> _items = [];

  /// image id -> stored file name (never exposed to the UI).
  final Map<String, String> _imageFiles = {};
  int _seq = 10;
  bool _loaded = false;
  Future<void> _queue = Future.value();

  /// Serializes operations so concurrent taps cannot interleave file writes.
  Future<T> _run<T>(Future<T> Function() op) {
    final completer = Completer<T>();
    _queue = _queue.then((_) async {
      try {
        await _ensureLoaded();
        completer.complete(await op());
      } catch (e, st) {
        completer.completeError(e, st);
      }
    });
    return completer.future;
  }

  Future<void> _ensureLoaded() async {
    if (_loaded) return;
    final state = decodeState(await _store.readState());
    _items.clear();
    _imageFiles.clear();
    if (state == null) {
      _items.addAll(_seed());
      _seq = 10;
      await _save();
    } else {
      try {
        for (final raw in (state['items'] as List)) {
          _items.add(MaterialItem.fromJson(raw));
        }
        final files = state['image_files'];
        if (files is Map) {
          files.forEach((k, v) => _imageFiles['$k'] = '$v');
        }
        _seq = state['seq'] as int? ?? 10;
      } catch (_) {
        _items
          ..clear()
          ..addAll(_seed());
        _imageFiles.clear();
        _seq = 10;
        await _save();
      }
    }
    _loaded = true;
  }

  Future<void> _save() => _store.writeState(jsonEncode({
        'v': 1,
        'seq': _seq,
        'items': _items.map(_toJson).toList(),
        'image_files': _imageFiles,
      }));

  /// Same shape as the API `MaterialOut`, so [MaterialItem.fromJson] reads it back.
  static Map<String, Object?> _toJson(MaterialItem m) => {
        'id': m.id,
        'name': m.name,
        'status': m.status.api,
        'version': m.version,
        'material_type': m.materialType?.api,
        'composition': m.composition,
        'scrap_size': m.scrapSize,
        'condition': m.condition?.api,
        'price_per_kg': m.pricePerKg,
        'city': m.city,
        'available_kg': m.availableKg,
        'confirmed_at': m.confirmedAt?.toUtc().toIso8601String(),
        'is_confirmation_current': m.isConfirmationCurrent,
        'balance': m.balance == null
            ? null
            : {
                'total_kg': m.balance!.totalKg,
                'available_kg': m.balance!.availableKg,
                'held_kg': m.balance!.heldKg,
                'transferred_kg': m.balance!.transferredKg,
                'internally_used_kg': m.balance!.internallyUsedKg,
              },
        'images': [
          for (final i in m.images)
            {
              'id': i.id,
              'mime_type': i.mimeType,
              'size_bytes': i.sizeBytes,
              'sort_order': i.sortOrder,
            }
        ],
      };

  List<MaterialItem> _seed() => [
        _make('1', 'Демо-партия: хлопковые обрезки', MaterialStatus.draft,
            TextileType.cotton, '120.500', 'Бишкек'),
        _make('2', 'Демо-партия: трикотаж', MaterialStatus.available,
            TextileType.knit, '45.000', 'Ош'),
        _make('3', 'Демо-партия: деним', MaterialStatus.reserved,
            TextileType.denim, '80.000', 'Бишкек'),
      ];

  @override
  Future<void> resetDemoData() => _run(() async {
        await _store.clear();
        _items
          ..clear()
          ..addAll(_seed());
        _imageFiles.clear();
        _seq = 10;
        await _save();
      });

  static MaterialItem _make(String n, String name, MaterialStatus status,
          TextileType type, String kg, String city) =>
      MaterialItem(
        id: '00000000-0000-0000-0000-00000000010$n',
        name: name,
        status: status,
        version: 1,
        availableKg: kg,
        materialType: type,
        condition: MaterialCondition.good,
        city: city,
        images: const [],
        balance: MassBalance(
          totalKg: kg,
          availableKg: kg,
          heldKg: '0.000',
          transferredKg: '0.000',
          internallyUsedKg: '0.000',
        ),
      );

  ApiException get _notFound => const ApiException(
      code: 'NOT_FOUND', message: 'Партия не найдена.', statusCode: 404);

  int _indexOf(String id) {
    final i = _items.indexWhere((m) => m.id == id);
    if (i < 0) throw _notFound;
    return i;
  }

  @override
  Future<MaterialListPage> list({
    MaterialStatus? status,
    int page = 1,
    int pageSize = 20,
    CatalogFilter filter = const CatalogFilter(),
  }) =>
      _run(() async {
        final q = filter.q.trim().toLowerCase();
        final city = filter.city.trim().toLowerCase();
        // Demo only: the real server does this filtering.
        final list = _items
            .where((m) => !publicView || _published(m))
            .where((m) => status == null || m.status == status)
            .where((m) => q.isEmpty || m.name.toLowerCase().contains(q))
            .where((m) => filter.type == null || m.materialType == filter.type)
            .where((m) =>
                filter.condition == null || m.condition == filter.condition)
            .where((m) => city.isEmpty || (m.city ?? '').toLowerCase() == city)
            .map(_viewOf)
            .toList();
        final start = (page - 1) * pageSize;
        final slice = start >= list.length
            ? <MaterialItem>[]
            : list.skip(start).take(pageSize).toList();
        return MaterialListPage(
            items: slice, page: page, pageSize: pageSize, total: list.length);
      });

  @override
  Future<MaterialItem> get(String id) => _run(() async {
        final m = _items[_indexOf(id)];
        if (publicView && !_published(m)) throw _notFound;
        return _viewOf(m);
      });

  @override
  Future<MaterialItem> create(MaterialCreate input) => _run(() async {
        final id = '00000000-0000-0000-0000-0000000002${_seq++}';
        final m = MaterialItem(
          id: id,
          name: input.name,
          status: MaterialStatus.draft,
          version: 1,
          availableKg: input.totalKg,
          materialType: input.materialType,
          condition: input.condition,
          city: input.city,
          pricePerKg: input.pricePerKg,
          composition: input.composition,
          scrapSize: input.scrapSize,
          images: const [],
          balance: MassBalance(
            totalKg: input.totalKg,
            availableKg: input.totalKg,
            heldKg: '0.000',
            transferredKg: '0.000',
            internallyUsedKg: '0.000',
          ),
        );
        _items.insert(0, m);
        await _save();
        return m;
      });

  ApiException _archivedConflict(String action) => ApiException(
        code: 'INVALID_TRANSITION',
        message: 'Партия в архиве, изменения недоступны.',
        statusCode: 409,
        details: {'from': 'archived', 'action': action},
      );

  /// A change of inputs or photos drops the confirmation; a published batch
  /// without obligations returns to draft (api.md 4, 19.5).
  MaterialItem _afterInputChange(MaterialItem next) {
    final b = next.balance;
    final free = b == null ||
        ((double.tryParse(b.heldKg) ?? 0) == 0 &&
            (double.tryParse(b.transferredKg) ?? 0) == 0);
    final back = free &&
        (next.status == MaterialStatus.available ||
            next.status == MaterialStatus.partiallyAllocated);
    return next.copyWith(
      isConfirmationCurrent: false,
      clearConfirmedAt: true,
      status: back ? MaterialStatus.draft : null,
    );
  }

  @override
  Future<MaterialItem> patch(String id, MaterialPatch patch) => _run(() async {
        final i = _indexOf(id);
        final cur = _items[i];
        if (cur.status == MaterialStatus.archived) {
          throw _archivedConflict('patch');
        }
        _checkVersion(cur, patch.version);
        final f = patch.fields;
        final total = f['total_kg'] as String? ?? cur.balance?.totalKg;
        final next = MaterialItem(
          id: cur.id,
          name: f['name'] as String? ?? cur.name,
          status: cur.status,
          version: cur.version + 1,
          availableKg: total ?? cur.availableKg,
          materialType: f.containsKey('material_type')
              ? TextileType.parse(f['material_type'])
              : cur.materialType,
          condition: f.containsKey('condition')
              ? MaterialCondition.parse(f['condition'])
              : cur.condition,
          city: f.containsKey('city') ? f['city'] as String? : cur.city,
          pricePerKg: f.containsKey('price_per_kg')
              ? f['price_per_kg'] as String?
              : cur.pricePerKg,
          composition: f.containsKey('composition')
              ? f['composition'] as String?
              : cur.composition,
          scrapSize: f.containsKey('scrap_size')
              ? f['scrap_size'] as String?
              : cur.scrapSize,
          images: cur.images,
          confirmedAt: cur.confirmedAt,
          isConfirmationCurrent: cur.isConfirmationCurrent,
          balance: cur.balance == null
              ? null
              : MassBalance(
                  totalKg: total ?? cur.balance!.totalKg,
                  availableKg: total ?? cur.balance!.availableKg,
                  heldKg: cur.balance!.heldKg,
                  transferredKg: cur.balance!.transferredKg,
                  internallyUsedKg: cur.balance!.internallyUsedKg,
                ),
        );
        final saved = _afterInputChange(next);
        _items[i] = saved;
        await _save();
        return saved;
      });

  @override
  Future<ImageUploadResult> uploadImage(String id, PickedPhoto photo) =>
      _run(() async {
        final i = _indexOf(id);
        final cur = _items[i];
        if (cur.status == MaterialStatus.archived) {
          throw _archivedConflict('images');
        }
        final problem = validatePhoto(photo);
        if (problem != null) {
          throw ApiException(
              code: 'VALIDATION_ERROR', message: problem, statusCode: 422);
        }
        if (cur.images.length >= _maxDemoPhotos) {
          throw const ApiException(
              code: 'VALIDATION_ERROR',
              message: 'Можно добавить не более 5 фото.',
              statusCode: 422);
        }
        final ext = _extensionOf(photo.bytes);
        // Copied into the private demo folder under a random name.
        final file = await _store.savePhoto(photo.bytes, ext);
        final image = MaterialImage(
          id: randomHex(16),
          mimeType: _mimeOf(ext),
          sizeBytes: photo.bytes.length,
          sortOrder: cur.images.length,
        );
        _imageFiles[image.id] = file;
        final saved = _afterInputChange(cur.copyWith(
            version: cur.version + 1, images: [...cur.images, image]));
        _items[i] = saved;
        await _save();
        return ImageUploadResult(image: image, materialVersion: saved.version);
      });

  @override
  Future<SignedUrl> imageUrl(String materialId, String imageId) =>
      _run(() async {
        final file = _imageFiles[imageId];
        final path = file == null ? null : await _store.photoPath(file);
        if (path == null) {
          throw const ApiException(
              code: 'NOT_FOUND',
              message: 'Демо: фото недоступно.',
              statusCode: 404);
        }
        // Local file, not a network URL; MaterialPhoto renders file:// itself.
        return SignedUrl(url: Uri.file(path).toString(), expiresAt: null);
      });

  @override
  Future<MaterialItem> confirm(String id, {required int version}) =>
      _run(() async {
        final i = _indexOf(id);
        final cur = _items[i];
        if (cur.status == MaterialStatus.archived) {
          throw _archivedConflict('confirm');
        }
        _checkVersion(cur, version);
        // Repeat on a current confirmation changes nothing (api.md 17.8).
        if (cur.isConfirmationCurrent) return cur;
        // Confirms the values already stored by the person; version is kept.
        final saved = cur.copyWith(
            confirmedAt: DateTime.now().toUtc(), isConfirmationCurrent: true);
        _items[i] = saved;
        await _save();
        return saved;
      });

  @override
  Future<MaterialItem> publish(String id, {required int version}) =>
      _run(() async {
        final i = _indexOf(id);
        final cur = _items[i];
        _checkVersion(cur, version);
        if (cur.status == MaterialStatus.archived) throw _invalidTransition;
        // Repeat on a published batch is a no-op (api.md 19.3).
        if (cur.status != MaterialStatus.draft) return cur;
        final missing = missingPublishFields(cur);
        if (missing.isNotEmpty) {
          throw ApiException(
            code: 'PUBLISH_REQUIREMENTS_NOT_MET',
            message: 'Не выполнены требования публикации.',
            statusCode: 422,
            details: {'missing': missing},
          );
        }
        // Publish keeps the version (api.md 19.2).
        final saved = cur.copyWith(status: MaterialStatus.available);
        _items[i] = saved;
        await _save();
        return saved;
      });

  @override
  Future<MaterialItem> archive(String id, {required int version}) =>
      _run(() async {
        final i = _indexOf(id);
        final cur = _items[i];
        _checkVersion(cur, version);
        if (cur.status == MaterialStatus.archived) return cur;
        final held = cur.balance?.heldKg ?? '0';
        if ((double.tryParse(held) ?? 0) > 0) {
          throw ApiException(
            code: 'ACTIVE_OBLIGATIONS',
            message: 'Есть активные резервы.',
            statusCode: 409,
            details: {'held_kg': held, 'reason': 'HELD_RESERVATIONS'},
          );
        }
        final saved = cur.copyWith(
            status: MaterialStatus.archived, version: cur.version + 1);
        _items[i] = saved;
        await _save();
        return saved;
      });

  ApiException get _invalidTransition => const ApiException(
      code: 'INVALID_TRANSITION',
      message: 'Недопустимый переход.',
      statusCode: 409);

  void _checkVersion(MaterialItem cur, int version) {
    if (version != cur.version) {
      throw ApiException(
        code: 'VERSION_CONFLICT',
        message: 'Данные изменились. Обновите партию.',
        statusCode: 409,
        details: {'current_version': cur.version},
      );
    }
  }
}
