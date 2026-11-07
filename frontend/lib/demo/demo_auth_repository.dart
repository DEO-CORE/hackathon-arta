// SYNTHETIC DEMO DATA. Used only when built with --dart-define=USE_DEMO_DATA=true.
// Nothing here comes from the server; the UI shows a "Демо" banner in this mode.
import '../features/auth/data/auth_repository.dart';
import '../features/auth/models/auth_models.dart';
import '../features/profile/data/organization_repository.dart';
import '../features/profile/models/organization.dart';
import '../core/network/api_exception.dart';

/// Synthetic demo credentials, shown on the login screen in demo builds only.
const demoLoginEmail = 'seller@demo.arta';
const demoLoginPassword = 'demo-password-1';

class DemoAuthRepository implements AuthRepository {
  final Map<String, RegisterRequest> _users = {
    'seller@demo.arta': const RegisterRequest(
      email: 'seller@demo.arta',
      password: 'demo-password-1',
      role: UserRole.enterprise,
      organizationName: 'Демо швейная фабрика',
      city: 'Бишкек',
      activityType: ActivityType.garmentFactory,
    ),
  };

  @override
  Future<LoginResult> login({
    required String email,
    required String password,
  }) async {
    final u = _users[email.toLowerCase()];
    if (u == null || u.password != password) {
      throw const ApiException(
        code: 'INVALID_CREDENTIALS',
        message: 'Неверный email или пароль.',
        statusCode: 401,
      );
    }
    return LoginResult(
      accessToken: 'demo-token',
      user: AuthUser(
        id: '00000000-0000-0000-0000-000000000001',
        email: u.email,
        role: u.role,
        organizationId: '00000000-0000-0000-0000-0000000000a1',
        active: true,
      ),
    );
  }

  @override
  Future<void> register(RegisterRequest request) async {
    final key = request.email.toLowerCase();
    if (_users.containsKey(key)) {
      throw const ApiException(
        code: 'EMAIL_ALREADY_REGISTERED',
        message: 'Этот email уже зарегистрирован.',
        statusCode: 409,
      );
    }
    _users[key] = request;
  }
}

class DemoOrganizationRepository implements OrganizationRepository {
  Organization _org = const Organization(
    id: '00000000-0000-0000-0000-0000000000a1',
    name: 'Демо швейная фабрика',
    city: 'Бишкек',
    activityType: ActivityType.garmentFactory,
    contacts: Contacts(),
  );

  @override
  Future<Organization> getMe() async => _org;

  @override
  Future<Organization> patchMe(OrganizationPatch patch) async {
    _org = _org.copyWith(
      name: patch.name,
      city: patch.city,
      activityType: patch.activityType,
      contacts: patch.contacts,
    );
    return _org;
  }
}
