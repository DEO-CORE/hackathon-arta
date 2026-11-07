import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../core/session/org_context.dart';
import '../core/session/session.dart';
import '../features/auth/providers/org_context_provider.dart';
import '../features/auth/presentation/login_screen.dart';
import '../features/auth/presentation/register_screen.dart';
import '../features/auth/presentation/verify_email_screen.dart';
import '../features/home/presentation/home_screen.dart';
import '../features/analysis/presentation/analysis_screen.dart';
import '../features/materials/presentation/catalog_screen.dart';
import '../features/materials/presentation/material_create_screen.dart';
import '../features/materials/presentation/material_detail_screen.dart';
import '../features/materials/presentation/material_edit_screen.dart';
import '../features/profile/presentation/organization_screen.dart';
import '../features/reservations/presentation/reservations_screen.dart';
import 'tab_transition.dart';

const _publicPaths = {'/login', '/register', '/verify-email'};

/// Pure guard so it can be tested without a widget tree. Returns null to stay.
String? authRedirect({
  required bool isAuthenticated,
  required String location,
  OrgContext? context,
}) {
  final isPublic = _publicPaths.contains(location);
  if (!isAuthenticated && !isPublic) return '/login';
  if (isAuthenticated && isPublic) return '/';
  // Role check only for signed-in users and never for the public pages. It is a
  // convenience: the server answers 403 regardless.
  if (isAuthenticated && context != null && !context.canOpen(location)) {
    return '/';
  }
  return null;
}

final routerProvider = Provider<GoRouter>((ref) {
  final refresh = ValueNotifier<int>(0);
  ref.listen(sessionProvider, (_, __) => refresh.value++);
  ref.listen(currentOrgContextProvider, (_, __) => refresh.value++);
  final router = GoRouter(
    initialLocation: '/',
    refreshListenable: refresh,
    redirect: (context, state) {
      final authed = ref.read(sessionProvider).isAuthenticated;
      final org = ref.read(currentOrgContextProvider);
      final target = authRedirect(
        isAuthenticated: authed,
        location: state.matchedLocation,
        context: org,
      );
      if (target == '/' &&
          authed &&
          org != null &&
          !org.canOpen(state.matchedLocation)) {
        // Explain why the user landed on the home screen.
        Future.microtask(() =>
            ref.read(routeNoticeProvider.notifier).state = roleBlockedMessage);
      }
      return target;
    },
    routes: [
      GoRoute(
        path: '/',
        pageBuilder: (ctx, st) => tabPage(ctx, st, const HomeScreen()),
      ),
      GoRoute(path: '/login', builder: (_, __) => const LoginScreen()),
      GoRoute(path: '/register', builder: (_, __) => const RegisterScreen()),
      GoRoute(
        path: '/verify-email',
        builder: (_, __) => const VerifyEmailScreen(),
      ),
      GoRoute(
        path: '/materials',
        pageBuilder: (ctx, st) => tabPage(ctx, st, const CatalogScreen()),
      ),
      GoRoute(
        path: '/materials/new',
        builder: (_, __) => const MaterialCreateScreen(),
      ),
      GoRoute(
        path: '/materials/:id',
        builder: (_, st) =>
            MaterialDetailScreen(materialId: st.pathParameters['id']!),
      ),
      GoRoute(
        path: '/materials/:id/edit',
        builder: (_, st) =>
            MaterialEditScreen(materialId: st.pathParameters['id']!),
      ),
      GoRoute(
        path: '/materials/:id/analysis',
        builder: (_, st) =>
            AnalysisScreen(materialId: st.pathParameters['id']!),
      ),
      GoRoute(
        path: '/reservations',
        pageBuilder: (ctx, st) => tabPage(ctx, st, const ReservationsScreen()),
      ),
      GoRoute(
        path: '/organization',
        pageBuilder: (ctx, st) => tabPage(ctx, st, const OrganizationScreen()),
      ),
    ],
  );
  ref.onDispose(() {
    router.dispose();
    refresh.dispose();
  });
  return router;
});
