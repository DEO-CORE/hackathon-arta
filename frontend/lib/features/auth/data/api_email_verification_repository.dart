import '../../../core/network/api_client.dart';
import 'email_verification_repository.dart';

/// docs/api.md section 23: POST /auth/email-code/send and /verify.
class ApiEmailVerificationRepository implements EmailVerificationRepository {
  ApiEmailVerificationRepository(this._client);
  final ApiClient _client;

  @override
  int get codeLength => 6;

  @override
  bool get sendsEmail => true;

  @override
  String? get notice => null;

  @override
  Future<int?> send(String email) => apiCall(() async {
        final r = await _client.dio.post<Map<String, dynamic>>(
          '/auth/email-code/send',
          data: {'email': email},
        );
        final v = r.data?['resend_after_seconds'];
        return v is int && v > 0 ? v : null;
      });

  @override
  Future<void> verify(String email, String code) => apiCall(() async {
        await _client.dio.post<Map<String, dynamic>>(
          '/auth/email-code/verify',
          data: {'email': email, 'code': code},
        );
      });
}
