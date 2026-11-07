import '../models/auth_models.dart';

/// Replaceable auth boundary: real API or synthetic demo implementation.
abstract class AuthRepository {
  Future<LoginResult> login({required String email, required String password});

  /// Creates user + organization. The API issues no token; call [login] next.
  Future<void> register(RegisterRequest request);
}
