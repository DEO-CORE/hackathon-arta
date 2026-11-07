import 'package:arta/app/tab_transition.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

GoRouter _router() => GoRouter(initialLocation: '/a', routes: [
      GoRoute(
        path: '/a',
        pageBuilder: (ctx, st) =>
            tabPage(ctx, st, const Scaffold(body: Text('tab A'))),
      ),
      GoRoute(
        path: '/b',
        pageBuilder: (ctx, st) =>
            tabPage(ctx, st, const Scaffold(body: Text('tab B'))),
      ),
    ]);

Future<void> _pump(WidgetTester tester, {bool reduceMotion = false}) async {
  await tester.pumpWidget(MediaQuery(
    data: MediaQueryData(disableAnimations: reduceMotion),
    child: MaterialApp.router(routerConfig: _router()),
  ));
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('switching tabs fades in the new tab instead of a hard cut',
      (tester) async {
    await _pump(tester);
    final ctx = tester.element(find.text('tab A'));
    GoRouter.of(ctx).go('/b');
    await tester.pump(); // start of the transition
    await tester.pump(const Duration(milliseconds: 100));
    expect(find.byType(FadeTransition), findsWidgets);
    expect(find.text('tab B'), findsOneWidget);
    await tester.pumpAndSettle();
    expect(find.text('tab A'), findsNothing);
  });

  testWidgets('reduce motion: the tab switch is instant, no fade',
      (tester) async {
    await _pump(tester, reduceMotion: true);
    final ctx = tester.element(find.text('tab A'));
    GoRouter.of(ctx).go('/b');
    await tester.pump();
    expect(find.text('tab B'), findsOneWidget);
    // The new tab must not sit under our fade (ancestors of its text).
    expect(
      find.ancestor(
          of: find.text('tab B'), matching: find.byType(FadeTransition)),
      findsNothing,
    );
  });
}
