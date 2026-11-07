import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../core/session/session.dart';
import '../features/auth/presentation/login_screen.dart';
import '../features/auth/presentation/register_screen.dart';
import '../features/home/presentation/home_screen.dart';
import '../features/analysis/presentation/analysis_screen.dart';
import '../features/materials/presentation/catalog_screen.dart';
import '../features/materials/presentation/material_create_screen.dart';
import '../features/materials/presentation/material_detail_screen.dart';
import '../features/materials/presentation/material_edit_screen.dart';
import '../features/profile/presentation/organization_screen.dart';

const _publicPaths = {'/login', '/register'};

/// Pure guard so it can be tested without a widget tree. Returns null to stay.
String? authRedirect(
    {required bool isAuthenticated, required String location}) {
  final isPublic = _publicPaths.contains(location);
  if (!isAuthenticated && !isPublic) return '/login';
  if (isAuthenticated && isPublic) return '/';
  return null;
}

final routerProvider = Provider<GoRouter>((ref) {
  final refresh = ValueNotifier<int>(0);
  ref.listen(sessionProvider, (_, __) => refresh.value++);
  final router = GoRouter(
    initialLocation: '/',
    refreshListenable: refresh,
    redirect: (context, state) => authRedirect(
      isAuthenticated: ref.read(sessionProvider).isAuthenticated,
      location: state.matchedLocation,
    ),
    routes: [
      GoRoute(path: '/', builder: (_, __) => const HomeScreen()),
      GoRoute(path: '/login', builder: (_, __) => const LoginScreen()),
      GoRoute(path: '/register', builder: (_, __) => const RegisterScreen()),
      GoRoute(path: '/materials', builder: (_, __) => const CatalogScreen()),
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
        path: '/organization',
        builder: (_, __) => const OrganizationScreen(),
      ),
    ],
  );
  ref.onDispose(() {
    router.dispose();
    refresh.dispose();
  });
  return router;
});
