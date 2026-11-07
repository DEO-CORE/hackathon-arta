import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../features/auth/models/auth_models.dart';

/// Current auth session. Token is kept in memory only (MVP): a reload
/// requires a new login. Persistent storage is a later decision.
class SessionState {
  const SessionState({this.token, this.user, this.expired = false});

  final String? token;
  final AuthUser? user;

  /// True when the server rejected the token (401); shown on the login screen.
  final bool expired;

  bool get isAuthenticated => token != null && user != null;
}

class SessionController extends Notifier<SessionState> {
  @override
  SessionState build() => const SessionState();

  void signIn(LoginResult result) {
    state = SessionState(token: result.accessToken, user: result.user);
  }

  void signOut() => state = const SessionState();

  void expire() {
    if (state.isAuthenticated) state = const SessionState(expired: true);
  }
}

final sessionProvider =
    NotifierProvider<SessionController, SessionState>(SessionController.new);
