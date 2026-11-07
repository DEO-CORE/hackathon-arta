import 'package:dio/dio.dart';

import '../../../core/network/api_client.dart';
import '../models/material_enums.dart';
import '../models/material_input.dart';
import '../models/material_models.dart';
import '../models/material_rules.dart';

abstract class MaterialRepository {
  Future<MaterialListPage> list({
    MaterialStatus? status,
    int page = 1,
    int pageSize = 20,
  });
  Future<MaterialItem> get(String id);
  Future<MaterialItem> create(MaterialCreate input);
  Future<MaterialItem> patch(String id, MaterialPatch patch);
  Future<ImageUploadResult> uploadImage(String id, PickedPhoto photo);
  Future<SignedUrl> imageUrl(String materialId, String imageId);
  Future<MaterialItem> confirm(String id, {required int version});

  /// draft -> available. The server checks the requirements (api.md 8.7).
  Future<MaterialItem> publish(String id, {required int version});

  /// Hides the material (api.md 8.8); refused while reservations are active.
  Future<MaterialItem> archive(String id, {required int version});
}

class ApiMaterialRepository implements MaterialRepository {
  ApiMaterialRepository(this._client);
  final ApiClient _client;

  @override
  Future<MaterialListPage> list({
    MaterialStatus? status,
    int page = 1,
    int pageSize = 20,
  }) =>
      apiCall(() async {
        final r = await _client.dio.get<Object>(
          '/materials',
          queryParameters: {
            'page': page,
            'page_size': pageSize,
            if (status != null) 'status': status.api,
          },
        );
        return MaterialListPage.fromJson(r.data);
      });

  @override
  Future<MaterialItem> get(String id) => apiCall(() async {
        final r = await _client.dio.get<Object>('/materials/$id');
        return MaterialItem.fromJson(r.data);
      });

  @override
  Future<MaterialItem> create(MaterialCreate input) => apiCall(() async {
        final r =
            await _client.dio.post<Object>('/materials', data: input.toJson());
        return MaterialItem.fromJson(r.data);
      });

  @override
  Future<MaterialItem> patch(String id, MaterialPatch patch) =>
      apiCall(() async {
        final r = await _client.dio
            .patch<Object>('/materials/$id', data: patch.toJson());
        return MaterialItem.fromJson(r.data);
      });

  @override
  Future<ImageUploadResult> uploadImage(String id, PickedPhoto photo) =>
      apiCall(() async {
        // Boundary is set by Dio; the client file name and type are ignored by the server.
        final form = FormData.fromMap({
          'file': MultipartFile.fromBytes(photo.bytes, filename: photo.name),
        });
        final r = await _client.dio.post<Object>(
          '/materials/$id/images',
          data: form,
          options: Options(contentType: Headers.multipartFormDataContentType),
        );
        return ImageUploadResult.fromJson(r.data);
      });

  @override
  Future<SignedUrl> imageUrl(String materialId, String imageId) =>
      apiCall(() async {
        final r = await _client.dio
            .get<Object>('/materials/$materialId/images/$imageId/url');
        return SignedUrl.fromJson(r.data);
      });

  @override
  Future<MaterialItem> confirm(String id, {required int version}) =>
      apiCall(() async {
        final r = await _client.dio
            .post<Object>('/materials/$id/confirm', data: {'version': version});
        return MaterialItem.fromJson(r.data);
      });

  @override
  Future<MaterialItem> publish(String id, {required int version}) =>
      _transition(id, 'publish', version);

  @override
  Future<MaterialItem> archive(String id, {required int version}) =>
      _transition(id, 'archive', version);

  Future<MaterialItem> _transition(String id, String action, int version) =>
      apiCall(() async {
        final r = await _client.dio
            .post<Object>('/materials/$id/$action', data: {'version': version});
        return MaterialItem.fromJson(r.data);
      });
}
