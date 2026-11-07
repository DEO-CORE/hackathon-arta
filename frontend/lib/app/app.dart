import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/session/reset_user_state.dart';
import '../core/session/session.dart';
import 'router.dart';
import 'theme.dart';

class ArtaApp extends ConsumerWidget {
  const ArtaApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Signing out (or an expired token) must not leave the previous user's
    // context behind.
    ref.listen(sessionProvider.select((s) => s.isAuthenticated), (prev, next) {
      if (prev == true && !next) resetUserScopedState(ref);
    });
    return MaterialApp.router(
      debugShowCheckedModeBanner: false,
      title: 'ARTA',
      theme: buildTheme(),
      routerConfig: ref.watch(routerProvider),
    );
  }
}
