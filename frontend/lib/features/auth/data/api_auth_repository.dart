import '../../../core/network/api_client.dart';
import '../models/auth_models.dart';
import 'auth_repository.dart';

class ApiAuthRepository implements AuthRepository {
  ApiAuthRepository(this._client);
  final ApiClient _client;

  @override
  Future<LoginResult> login({
    required String email,
    required String password,
  }) =>
      apiCall(() async {
        final r = await _client.dio.post<Map<String, dynamic>>(
          '/auth/login',
          data: {'email': email, 'password': password},
        );
        return LoginResult.fromJson(r.data!);
      });

  @override
  Future<void> register(RegisterRequest request) => apiCall(() async {
        await _client.dio.post<Map<String, dynamic>>(
          '/auth/register',
          data: request.toJson(),
        );
      });
}
