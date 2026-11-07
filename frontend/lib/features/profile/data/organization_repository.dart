import '../../../core/network/api_client.dart';
import '../models/organization.dart';

abstract class OrganizationRepository {
  Future<Organization> getMe();
  Future<Organization> patchMe(OrganizationPatch patch);
}

class ApiOrganizationRepository implements OrganizationRepository {
  ApiOrganizationRepository(this._client);
  final ApiClient _client;

  @override
  Future<Organization> getMe() => apiCall(() async {
        final r =
            await _client.dio.get<Map<String, dynamic>>('/organizations/me');
        return Organization.fromJson(r.data!);
      });

  @override
  Future<Organization> patchMe(OrganizationPatch patch) => apiCall(() async {
        final r = await _client.dio.patch<Map<String, dynamic>>(
          '/organizations/me',
          data: patch.toJson(),
        );
        return Organization.fromJson(r.data!);
      });
}
