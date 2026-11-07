import 'dart:io' show Directory;

import 'package:flutter/foundation.dart' show kIsWeb, listEquals;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';

import '../../../core/config/app_config.dart';
import '../../../core/network/api_client.dart';
import '../../../core/network/api_exception.dart';
import '../../../demo/demo_material_repository.dart';
import '../../../demo/demo_store.dart';
import '../data/material_repository.dart';
import '../models/material_enums.dart';
import '../models/material_input.dart';
import '../models/material_models.dart';
import '../models/material_rules.dart';

/// Demo data is chosen only by the explicit USE_DEMO_DATA flag, never as a
/// fallback for network errors.
/// Demo files live in their own folder, apart from anything else the app stores.
/// On web there is no app folder, so the demo is memory-only there.
final demoStoreProvider = Provider<DemoStore>((ref) {
  if (kIsWeb) return MemoryDemoStore();
  return FileDemoStore(() async {
    final docs = await getApplicationDocumentsDirectory();
    return Directory('${docs.path}/demo_data');
  });
});

final materialRepositoryProvider = Provider<MaterialRepository>((ref) {
  if (ref.watch(appConfigProvider).useDemoData) {
    return DemoMaterialRepository(store: ref.watch(demoStoreProvider));
  }
  return ApiMaterialRepository(ref.watch(apiClientProvider));
});

ApiException _asApi(Object e) => e is ApiException ? e : ApiException.network();

// ---------------------------------------------------------------- detail

final materialDetailProvider =
    FutureProvider.autoDispose.family<MaterialItem, String>((ref, id) {
  return ref.watch(materialRepositoryProvider).get(id);
});

/// Signed URLs are short-lived; the provider is autoDispose so they are not kept.
final materialImageUrlProvider = FutureProvider.autoDispose
    .family<SignedUrl, ({String materialId, String imageId})>((ref, key) {
  return ref
      .watch(materialRepositoryProvider)
      .imageUrl(key.materialId, key.imageId);
});

// --------------------------------------------------------------- catalog

const catalogPageSize = 20;

class CatalogState {
  const CatalogState({
    this.items = const [],
    this.status,
    this.page = 0,
    this.total = 0,
    this.loading = true,
    this.loadingMore = false,
    this.error,
    this.loadMoreError,
  });

  final List<MaterialItem> items;
  final MaterialStatus? status;
  final int page;
  final int total;
  final bool loading;
  final bool loadingMore;
  final ApiException? error;
  final ApiException? loadMoreError;

  bool get hasMore => items.length < total;
}

class CatalogController extends AutoDisposeNotifier<CatalogState> {
  int _generation = 0;

  @override
  CatalogState build() {
    Future.microtask(reload);
    return const CatalogState();
  }

  Future<void> reload({MaterialStatus? status, bool keepStatus = true}) async {
    final filter = keepStatus ? (status ?? state.status) : status;
    final gen = ++_generation;
    state = CatalogState(status: filter);
    try {
      final page = await ref
          .read(materialRepositoryProvider)
          .list(status: filter, page: 1, pageSize: catalogPageSize);
      if (gen != _generation) return;
      state = CatalogState(
        status: filter,
        items: page.items,
        page: page.page,
        total: page.total,
        loading: false,
      );
    } catch (e) {
      if (gen != _generation) return;
      state = CatalogState(status: filter, loading: false, error: _asApi(e));
    }
  }

  Future<void> setStatus(MaterialStatus? status) =>
      reload(status: status, keepStatus: false);

  Future<void> loadMore() async {
    final s = state;
    if (s.loading || s.loadingMore || !s.hasMore) return;
    final gen = _generation;
    state = CatalogState(
      status: s.status,
      items: s.items,
      page: s.page,
      total: s.total,
      loading: false,
      loadingMore: true,
    );
    try {
      final next = await ref
          .read(materialRepositoryProvider)
          .list(status: s.status, page: s.page + 1, pageSize: catalogPageSize);
      if (gen != _generation) return;
      state = CatalogState(
        status: s.status,
        items: [...s.items, ...next.items],
        page: next.page,
        total: next.total,
        loading: false,
      );
    } catch (e) {
      if (gen != _generation) return;
      state = CatalogState(
        status: s.status,
        items: s.items,
        page: s.page,
        total: s.total,
        loading: false,
        loadMoreError: _asApi(e),
      );
    }
  }
}

final catalogProvider =
    AutoDisposeNotifierProvider<CatalogController, CatalogState>(
  CatalogController.new,
);

// ---------------------------------------------------------- photo picking

abstract class PhotoPicker {
  Future<List<PickedPhoto>> pick();
}

class GalleryPhotoPicker implements PhotoPicker {
  @override
  Future<List<PickedPhoto>> pick() async {
    final files = await ImagePicker().pickMultiImage();
    final result = <PickedPhoto>[];
    for (final f in files) {
      result.add(PickedPhoto(name: f.name, bytes: await f.readAsBytes()));
    }
    return result;
  }
}

final photoPickerProvider = Provider<PhotoPicker>((_) => GalleryPhotoPicker());

// ---------------------------------------------------------------- create

enum PhotoUploadStatus { pending, uploading, done, failed }

class PhotoUpload {
  const PhotoUpload({
    required this.photo,
    this.status = PhotoUploadStatus.pending,
    this.error,
  });

  final PickedPhoto photo;
  final PhotoUploadStatus status;
  final ApiException? error;

  PhotoUpload copyWith(PhotoUploadStatus status, {ApiException? error}) =>
      PhotoUpload(photo: photo, status: status, error: error);
}

class CreateState {
  const CreateState({
    this.saving = false,
    this.error,
    this.created,
    this.photos = const [],
    this.photoNotice,
  });

  final bool saving;
  final ApiException? error;

  /// Set once the draft exists on the server; the form is then locked and a
  /// retry only re-uploads failed photos instead of creating a duplicate.
  final MaterialItem? created;
  final List<PhotoUpload> photos;
  final String? photoNotice;

  bool get allPhotosDone =>
      photos.every((p) => p.status == PhotoUploadStatus.done);
  bool get completed => created != null && allPhotosDone && !saving;
}

class CreateController extends AutoDisposeNotifier<CreateState> {
  @override
  CreateState build() => const CreateState();

  /// Validates picked files and keeps the valid ones, up to the 5-photo limit.
  void addPhotos(List<PickedPhoto> picked) {
    if (state.saving || state.created != null) return;
    final photos = [...state.photos];
    final problems = <String>[];
    for (final p in picked) {
      if (photos.length >= maxPhotos) {
        problems.add('Можно добавить не более $maxPhotos фото.');
        break;
      }
      final err = validatePhoto(p);
      // Re-picking the same file must not create a second upload.
      final duplicate = photos.any(
          (e) => e.photo.name == p.name && listEquals(e.photo.bytes, p.bytes));
      if (duplicate) {
        problems.add('«${p.name}»: уже добавлено.');
      } else if (err != null) {
        problems.add(err);
      } else {
        photos.add(PhotoUpload(photo: p));
      }
    }
    state = CreateState(
      photos: photos,
      photoNotice: problems.isEmpty ? null : problems.join('\n'),
    );
  }

  void removePhoto(int index) {
    if (state.saving || state.created != null) return;
    final photos = [...state.photos]..removeAt(index);
    state = CreateState(photos: photos);
  }

  Future<void> submit(MaterialCreate input) async {
    if (state.saving) return;
    var created = state.created;
    state = _copy(saving: true, clearError: true);
    if (created == null) {
      try {
        created = await ref.read(materialRepositoryProvider).create(input);
      } catch (e) {
        state = _copy(saving: false, error: _asApi(e));
        return;
      }
      state = _copy(saving: true, created: created);
    }
    for (var i = 0; i < state.photos.length; i++) {
      if (state.photos[i].status == PhotoUploadStatus.done) continue;
      _setPhoto(i, PhotoUploadStatus.uploading);
      try {
        await ref
            .read(materialRepositoryProvider)
            .uploadImage(created.id, state.photos[i].photo);
        _setPhoto(i, PhotoUploadStatus.done);
      } catch (e) {
        _setPhoto(i, PhotoUploadStatus.failed, error: _asApi(e));
      }
    }
    state = _copy(saving: false);
  }

  void _setPhoto(int i, PhotoUploadStatus s, {ApiException? error}) {
    final photos = [...state.photos];
    photos[i] = photos[i].copyWith(s, error: error);
    state = _copy(photos: photos);
  }

  CreateState _copy({
    bool? saving,
    ApiException? error,
    bool clearError = false,
    MaterialItem? created,
    List<PhotoUpload>? photos,
  }) =>
      CreateState(
        saving: saving ?? state.saving,
        error: clearError ? null : (error ?? state.error),
        created: created ?? state.created,
        photos: photos ?? state.photos,
        photoNotice: state.photoNotice,
      );
}

final createMaterialProvider =
    AutoDisposeNotifierProvider<CreateController, CreateState>(
  CreateController.new,
);

// ------------------------------------------------------------------ edit

class EditState {
  const EditState({
    required this.base,
    this.saving = false,
    this.refreshing = false,
    this.error,
    this.saved,
  });

  /// Last server version the user is editing against.
  final MaterialItem base;
  final bool saving;
  final bool refreshing;
  final ApiException? error;
  final MaterialItem? saved;

  bool get isVersionConflict => error?.code == 'VERSION_CONFLICT';
  bool get isActiveObligations => error?.code == 'ACTIVE_OBLIGATIONS';

  int? get currentServerVersion {
    final v = error?.details?['current_version'];
    return v is int ? v : null;
  }
}

class EditController
    extends AutoDisposeFamilyNotifier<EditState, MaterialItem> {
  @override
  EditState build(MaterialItem arg) => EditState(base: arg);

  Future<void> save(Map<String, Object?> fields) async {
    if (state.saving || state.refreshing || fields.isEmpty) return;
    final base = state.base;
    state = EditState(base: base, saving: true);
    try {
      final item = await ref
          .read(materialRepositoryProvider)
          .patch(base.id, MaterialPatch(version: base.version, fields: fields));
      state = EditState(base: item, saved: item);
    } catch (e) {
      state = EditState(base: base, error: _asApi(e));
    }
  }

  /// Reloads the server version; the user's typed values stay in the form and
  /// the next save is diffed against the fresh base.
  Future<void> refresh() async {
    if (state.saving || state.refreshing) return;
    final prev = state;
    state = EditState(base: prev.base, refreshing: true, error: prev.error);
    try {
      final item = await ref.read(materialRepositoryProvider).get(prev.base.id);
      state = EditState(base: item);
    } catch (e) {
      state = EditState(base: prev.base, error: _asApi(e));
    }
  }
}

final editMaterialProvider =
    AutoDisposeNotifierProviderFamily<EditController, EditState, MaterialItem>(
        EditController.new);

// --------------------------------------------------------------- confirm

class ConfirmState {
  const ConfirmState({this.busy = false, this.error, this.done = false});
  final bool busy;
  final ApiException? error;
  final bool done;
}

/// Human confirmation of the displayed characteristics (no analysis id).
class ConfirmController extends AutoDisposeNotifier<ConfirmState> {
  @override
  ConfirmState build() => const ConfirmState();

  Future<void> confirm(MaterialItem m) async {
    if (state.busy) return;
    state = const ConfirmState(busy: true);
    try {
      await ref
          .read(materialRepositoryProvider)
          .confirm(m.id, version: m.version);
      ref.invalidate(materialDetailProvider(m.id));
      state = const ConfirmState(done: true);
    } catch (e) {
      state = ConfirmState(error: _asApi(e));
    }
  }
}

final confirmMaterialProvider =
    AutoDisposeNotifierProvider<ConfirmController, ConfirmState>(
  ConfirmController.new,
);

// ------------------------------------------------------------- lifecycle

enum LifecycleAction { publish, archive }

class LifecycleState {
  const LifecycleState({
    this.busy = false,
    this.error,
    this.item,
    this.lastAction,
  });

  final bool busy;
  final ApiException? error;

  /// Last server response; shown instead of computing the status locally.
  final MaterialItem? item;
  final LifecycleAction? lastAction;

  bool get isVersionConflict => error?.code == 'VERSION_CONFLICT';
  int? get currentServerVersion {
    final v = error?.details?['current_version'];
    return v is int ? v : null;
  }
}

/// Publish and archive. Always sends the version of the last server response
/// and replaces the card with the response body.
class LifecycleController extends AutoDisposeNotifier<LifecycleState> {
  @override
  LifecycleState build() => const LifecycleState();

  Future<void> publish(MaterialItem m) => _run(LifecycleAction.publish, m);
  Future<void> archive(MaterialItem m) => _run(LifecycleAction.archive, m);

  Future<void> _run(LifecycleAction action, MaterialItem m) async {
    if (state.busy) return;
    state = LifecycleState(busy: true, item: state.item, lastAction: action);
    final repo = ref.read(materialRepositoryProvider);
    try {
      final item = action == LifecycleAction.publish
          ? await repo.publish(m.id, version: m.version)
          : await repo.archive(m.id, version: m.version);
      state = LifecycleState(item: item, lastAction: action);
      // The catalog may be open behind the card; reload what the server returns.
      ref.invalidate(catalogProvider);
    } catch (e) {
      final err = _asApi(e);
      state = LifecycleState(item: state.item, error: err, lastAction: action);
      // A lost archive response makes the retry stale (api.md 19.4): re-read
      // the card so the user sees the real status.
      if (action == LifecycleAction.archive && state.isVersionConflict) {
        ref.invalidate(materialDetailProvider(m.id));
      }
    }
  }

  /// "Обновить данные": drop the local copy and the error, reload from server.
  void refresh(String id) {
    if (state.busy) return;
    state = const LifecycleState();
    ref.invalidate(materialDetailProvider(id));
  }
}

final lifecycleProvider =
    AutoDisposeNotifierProvider<LifecycleController, LifecycleState>(
  LifecycleController.new,
);
