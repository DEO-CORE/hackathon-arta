/// Provider-independent boundary for email confirmation by code. Demo and API
/// implementations are chosen explicitly (demo only with USE_DEMO_DATA=true);
/// there is never a silent switch between them.
abstract class EmailVerificationRepository {
  /// Digits in the code: 6 for the API, 4 for the demo code.
  int get codeLength;

  /// True when a real email is sent (API). The demo sends nothing.
  bool get sendsEmail;

  /// Explanation of the mode shown on screen (demo only), else null.
  String? get notice;

  /// Requests a code. Returns the pause before the next send in seconds, when
  /// the server states one. Throws ApiException (429, 503, ...).
  Future<int?> send(String email);

  /// Confirms the email. Throws ApiException: 409 INVALID_CODE (details
  /// `attempts_left`), 409 CODE_EXPIRED, 429, ... No token is issued; the user
  /// signs in with the password afterwards.
  Future<void> verify(String email, String code);
}
