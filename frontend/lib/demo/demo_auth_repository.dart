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

/// Synthetic demo accounts of the other roles. No demo admin exists.
const demoBuyerEmail = 'buyer@demo.arta';
const demoBuyerPassword = 'demo-buyer-1';
const demoRecyclerEmail = 'recycler@demo.arta';
const demoRecyclerPassword = 'demo-recycler-1';

const _demoSellerOrgId = '00000000-0000-0000-0000-0000000000a1';
const _demoBuyerOrgId = '00000000-0000-0000-0000-0000000000b1';
const _demoRecyclerOrgId = '00000000-0000-0000-0000-0000000000c1';

String _demoOrgIdFor(String email) => switch (email.toLowerCase()) {
      demoBuyerEmail => _demoBuyerOrgId,
      demoRecyclerEmail => _demoRecyclerOrgId,
      _ => _demoSellerOrgId,
    };

/// Demo organization fixture of an account (seller by default).
Organization demoOrganizationFor(String? email) {
  final e = (email ?? '').toLowerCase();
  if (e == demoBuyerEmail) {
    return Organization(
      id: _demoBuyerOrgId,
      name: 'Демо мастерская',
      city: 'Ош',
      activityType: ActivityType.workshop,
      contacts: const Contacts(),
    );
  }
  if (e == demoRecyclerEmail) {
    return Organization(
      id: _demoRecyclerOrgId,
      name: 'Демо переработка',
      city: 'Бишкек',
      activityType: ActivityType.recycler,
      contacts: const Contacts(),
    );
  }
  return Organization(
    id: _demoSellerOrgId,
    name: 'Демо швейная фабрика',
    city: 'Бишкек',
    activityType: ActivityType.garmentFactory,
    contacts: const Contacts(),
  );
}

class DemoAuthRepository implements AuthRepository {
  final Map<String, RegisterRequest> _users = {
    demoBuyerEmail: const RegisterRequest(
      email: demoBuyerEmail,
      password: demoBuyerPassword,
      role: UserRole.buyer,
      organizationName: 'Демо мастерская',
      city: 'Ош',
      activityType: ActivityType.workshop,
    ),
    demoRecyclerEmail: const RegisterRequest(
      email: demoRecyclerEmail,
      password: demoRecyclerPassword,
      role: UserRole.buyer,
      organizationName: 'Демо переработка',
      city: 'Бишкек',
      activityType: ActivityType.recycler,
    ),
    'seller@demo.arta': const RegisterRequest(
      email: 'seller@demo.arta',
      password: 'demo-password-1',
      role: UserRole.enterprise,
      organizationName: 'Демо швейная фабрика',
      city: 'Бишкек',
      activityType: ActivityType.garmentFactory,
    ),
  };

  /// The seeded demo seller may always sign in; new demo accounts must pass
  /// the (demo) email confirmation first, like the real flow.
  final Set<String> _confirmed = {
    'seller@demo.arta',
    demoBuyerEmail,
    demoRecyclerEmail,
  };

  void confirmEmail(String email) => _confirmed.add(email.toLowerCase());

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
    if (!_confirmed.contains(u.email.toLowerCase())) {
      throw const ApiException(
        code: 'EMAIL_NOT_CONFIRMED',
        message: 'Email не подтверждён.',
        statusCode: 403,
      );
    }
    return LoginResult(
      accessToken: 'demo-token',
      user: AuthUser(
        id: '00000000-0000-0000-0000-000000000001',
        email: u.email,
        role: u.role,
        organizationId: _demoOrgIdFor(u.email),
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
  DemoOrganizationRepository({String? email})
      : _org = demoOrganizationFor(email);

  Organization _org;

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
