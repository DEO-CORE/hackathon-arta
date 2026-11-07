import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/config/app_config.dart';
import '../../../core/network/api_client.dart';
import '../../../core/session/org_context.dart';
import '../../../core/session/session.dart';
import '../../../demo/demo_auth_repository.dart';
import '../models/auth_models.dart';

/// Where the organization context comes from: GET /auth/me in API mode,
/// fixtures in the demo. No silent switching between them.
abstract class OrgContextSource {
  Future<OrgContext> load(AuthUser user);
}

class ApiOrgContextSource implements OrgContextSource {
  ApiOrgContextSource(this._client);
  final ApiClient _client;

  @override
  Future<OrgContext> load(AuthUser user) => apiCall(() async {
        final r = await _client.dio.get<Map<String, dynamic>>('/auth/me');
        return OrgContext.fromMe(r.data!);
      });
}

/// Demo fixtures only (USE_DEMO_DATA=true): specialization comes from the demo
/// organization of that account.
class DemoOrgContextSource implements OrgContextSource {
  @override
  Future<OrgContext> load(AuthUser user) async => OrgContext.fromUser(user,
      activity: demoOrganizationFor(user.email).activityType);
}

final orgContextSourceProvider = Provider<OrgContextSource>((ref) {
  return ref.watch(appConfigProvider).useDemoData
      ? DemoOrgContextSource()
      : ApiOrgContextSource(ref.watch(apiClientProvider));
});

/// Kept alive (not autoDispose) so every screen shares one context; it is
/// rebuilt when the signed-in user changes and is null when signed out.
class OrgContextController extends AsyncNotifier<OrgContext?> {
  @override
  Future<OrgContext?> build() async {
    final user = ref.watch(sessionProvider.select((s) => s.user));
    if (user == null) return null;
    return ref.watch(orgContextSourceProvider).load(user);
  }
}

final orgContextProvider =
    AsyncNotifierProvider<OrgContextController, OrgContext?>(
  OrgContextController.new,
);

/// Synchronous view for the UI: the loaded context, else the one derived from
/// the session, so screens never wait for it. Null when signed out.
final currentOrgContextProvider = Provider<OrgContext?>((ref) {
  final loaded = ref.watch(orgContextProvider).valueOrNull;
  if (loaded != null) return loaded;
  final user = ref.watch(sessionProvider.select((s) => s.user));
  return user == null ? null : OrgContext.fromUser(user);
});

/// Display-only permission check; the server enforces the rule.
final canProvider = Provider.family<bool, String>((ref, permission) =>
    ref.watch(currentOrgContextProvider)?.can(permission) ?? false);

/// One-shot message after a role-incompatible route was redirected.
final routeNoticeProvider = StateProvider<String?>((ref) => null);
