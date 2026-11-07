import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/config/app_config.dart';
import '../../../core/network/api_client.dart';
import '../../../core/network/api_exception.dart';
import '../../../core/session/session.dart';
import '../../../demo/demo_auth_repository.dart';
import '../data/api_auth_repository.dart';
import '../data/auth_repository.dart';
import '../models/auth_models.dart';

/// Real API by default; demo only with explicit USE_DEMO_DATA=true.
final authRepositoryProvider = Provider<AuthRepository>((ref) {
  if (ref.watch(appConfigProvider).useDemoData) return DemoAuthRepository();
  return ApiAuthRepository(ref.watch(apiClientProvider));
});

class AuthFormState {
  const AuthFormState({this.submitting = false, this.error});
  final bool submitting;
  final ApiException? error;
}

/// Shared by the login and register forms; blocks re-entry while in flight.
class AuthFormController extends AutoDisposeNotifier<AuthFormState> {
  @override
  AuthFormState build() => const AuthFormState();

  Future<void> login(String email, String password) => _run(() async {
        final result = await ref
            .read(authRepositoryProvider)
            .login(email: email, password: password);
        ref.read(sessionProvider.notifier).signIn(result);
      });

  Future<void> register(RegisterRequest request) => _run(() async {
        final repo = ref.read(authRepositoryProvider);
        await repo.register(request);
        final result =
            await repo.login(email: request.email, password: request.password);
        ref.read(sessionProvider.notifier).signIn(result);
      });

  Future<void> _run(Future<void> Function() action) async {
    if (state.submitting) return;
    state = const AuthFormState(submitting: true);
    try {
      await action();
      state = const AuthFormState();
    } on ApiException catch (e) {
      state = AuthFormState(error: e);
    } catch (_) {
      state = AuthFormState(error: ApiException.network());
    }
  }
}

final authFormProvider =
    AutoDisposeNotifierProvider<AuthFormController, AuthFormState>(
  AuthFormController.new,
);
