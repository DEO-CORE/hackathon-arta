// SYNTHETIC DEMO BEHAVIOUR. Used only with --dart-define=USE_DEMO_DATA=true.
// No email is sent and the only accepted code is the fixed demo code. This
// file must never be reachable from a production build path.
import '../core/network/api_exception.dart';
import '../features/auth/data/email_verification_repository.dart';

const demoEmailCode = '7777';

class DemoEmailVerificationRepository implements EmailVerificationRepository {
  DemoEmailVerificationRepository({this.onConfirmed});

  /// Lets the demo auth repository learn that the email is confirmed.
  final void Function(String email)? onConfirmed;

  @override
  int get codeLength => demoEmailCode.length;

  @override
  bool get sendsEmail => false;

  @override
  String? get notice => 'Демо: письмо не отправляется, код $demoEmailCode';

  @override
  Future<int?> send(String email) async => 60;

  @override
  Future<void> verify(String email, String code) async {
    if (code != demoEmailCode) {
      throw const ApiException(
          code: 'INVALID_CODE', message: 'Неверный код.', statusCode: 409);
    }
    onConfirmed?.call(email);
  }
}
