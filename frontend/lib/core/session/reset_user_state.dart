import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../features/analysis/providers/analysis_providers.dart';
import '../../features/auth/providers/auth_providers.dart';
import '../../features/auth/providers/org_context_provider.dart';
import '../../features/materials/providers/material_providers.dart';
import '../../features/profile/providers/organization_providers.dart';

/// Drops every kept-alive provider that holds data of the signed-in user, so
/// the next user never sees the previous one's context, repositories or
/// notices. AutoDispose providers (catalog, details, forms) go away by
/// themselves when their screens close.
void resetUserScopedState(WidgetRef ref) {
  ref.invalidate(orgContextProvider);
  ref.invalidate(routeNoticeProvider);
  ref.invalidate(pendingEmailProvider);
  ref.invalidate(loginNoticeProvider);
  ref.invalidate(materialRepositoryProvider);
  ref.invalidate(organizationRepositoryProvider);
  ref.invalidate(analysisBackendProvider);
}
