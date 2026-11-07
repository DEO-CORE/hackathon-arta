import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../core/session/session.dart';
import '../core/ui/ui.dart';
import '../features/auth/models/auth_models.dart';

enum AppTab { home, materials, reservations, organization }

/// Wraps a tab screen with the floating nav (phone) or rail (wide). It is a
/// plain widget, not a ShellRoute: routes and the auth guard stay as they are.
/// Tabs use `go`, so a tab screen's back control must not depend on the stack
/// (see [tabBack]).
class AppTabShell extends ConsumerWidget {
  const AppTabShell({super.key, required this.tab, required this.child});

  final AppTab tab;
  final Widget child;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isEnterprise =
        ref.watch(sessionProvider).user?.role == UserRole.enterprise;
    final items = [
      const AppNavItem(
          label: 'Главная',
          icon: Icons.home_outlined,
          selectedIcon: Icons.home,
          route: '/'),
      AppNavItem(
          label: isEnterprise ? 'Партии' : 'Каталог',
          icon: Icons.inventory_2_outlined,
          selectedIcon: Icons.inventory_2,
          route: '/materials'),
      AppNavItem(
          label: isEnterprise ? 'Сделки' : 'Заявки',
          icon: Icons.swap_horiz_outlined,
          selectedIcon: Icons.swap_horiz,
          route: '/reservations'),
      const AppNavItem(
          label: 'Организация',
          icon: Icons.business_outlined,
          selectedIcon: Icons.business,
          route: '/organization'),
    ];
    return AppShell(
      items: items,
      currentIndex: tab.index,
      onSelected: (i) {
        if (i != tab.index) context.go(items[i].route);
      },
      child: child,
    );
  }
}

/// Back from a tab screen: pops when possible, otherwise goes home, so the
/// arrow never disappears after tab navigation.
VoidCallback tabBack(BuildContext context) => () {
      if (context.canPop()) {
        context.pop();
      } else {
        context.go('/');
      }
    };
