import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

/// Page for the four bottom-nav destinations. Tabs switch by `go`, so the
/// transition is a short fade with a small upward slide instead of a hard cut.
/// Respects the system "reduce motion" setting: the switch is then instant.
Page<void> tabPage(BuildContext context, GoRouterState state, Widget child) {
  // Duration is fixed when the page is built, so the setting is read here.
  final reduce = MediaQuery.disableAnimationsOf(context);
  return CustomTransitionPage<void>(
    key: state.pageKey,
    child: child,
    transitionDuration:
        reduce ? Duration.zero : const Duration(milliseconds: 260),
    reverseTransitionDuration:
        reduce ? Duration.zero : const Duration(milliseconds: 200),
    transitionsBuilder: (context, animation, secondary, child) {
      if (reduce) return child;
      final curved = CurvedAnimation(
        parent: animation,
        curve: Curves.easeOutCubic,
        reverseCurve: Curves.easeInCubic,
      );
      return FadeTransition(
        opacity: curved,
        child: SlideTransition(
          position: Tween<Offset>(
            begin: const Offset(0, 0.015),
            end: Offset.zero,
          ).animate(curved),
          child: child,
        ),
      );
    },
  );
}
