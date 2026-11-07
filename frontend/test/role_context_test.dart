import 'package:arta/app/app.dart';
import 'package:arta/app/router.dart';
import 'package:arta/core/config/app_config.dart';
import 'package:arta/core/network/api_exception.dart';
import 'package:arta/core/session/org_context.dart';
import 'package:arta/core/session/session.dart';
import 'package:arta/core/ui/ui.dart';
import 'package:arta/core/widgets/error_panel.dart';
import 'package:arta/features/home/presentation/pending_review_screen.dart';
import 'package:arta/demo/demo_auth_repository.dart';
import 'package:arta/demo/demo_material_repository.dart';
import 'package:arta/features/auth/models/auth_models.dart';
import 'package:arta/features/auth/providers/org_context_provider.dart';
import 'package:arta/features/materials/models/material_enums.dart';
import 'package:arta/features/materials/providers/material_providers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/material_fakes.dart';

AuthUser _user(UserRole role, {String email = 'u@x.test'}) => AuthUser(
    id: 'u', email: email, role: role, organizationId: 'o', active: true);

Future<ProviderContainer> _app(
  WidgetTester tester,
  RecordingRepo repo, {
  required AuthUser user,
  bool demo = false,
  Size size = const Size(360, 800),
}) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  final c = ProviderContainer(overrides: [
    appConfigProvider
        .overrideWithValue(AppConfig(apiBaseUrl: '', useDemoData: demo)),
    materialRepositoryProvider.overrideWithValue(repo),
    if (!demo)
      orgContextSourceProvider.overrideWithValue(FixtureOrgContextSource()),
  ]);
  addTearDown(c.dispose);
  c
      .read(sessionProvider.notifier)
      .signIn(LoginResult(accessToken: 't', user: user));
  await tester.pumpWidget(
      UncontrolledProviderScope(container: c, child: const ArtaApp()));
  await tester.pumpAndSettle();
  return c;
}

class _FakeMe implements OrgContextSource {
  _FakeMe(this.ctx);
  final OrgContext ctx;
  @override
  Future<OrgContext> load(AuthUser user) async => ctx;
}

void main() {
  group('OrgContext', () {
    test('supplier, buyer and recycler', () {
      final s = OrgContext.fromUser(_user(UserRole.enterprise));
      expect(s.isSupplier, isTrue);
      expect(s.roleLabel, 'Предприятие');
      expect(s.can(Perm.materialsCreate), isTrue);
      final b = OrgContext.fromUser(_user(UserRole.buyer));
      expect(b.orgType, OrgType.buyer);
      expect(b.roleLabel, 'Покупатель');
      expect(b.can(Perm.materialsCreate), isFalse);
      expect(b.can(Perm.catalogView), isTrue);
      final r = OrgContext.fromUser(_user(UserRole.buyer),
          activity: ActivityType.recycler);
      expect(r.isRecycler, isTrue);
      expect(r.roleLabel, 'Переработчик');
      expect(r.isSupplier, isFalse);
    });

    test('routes: buyer cannot open supplier-only pages', () {
      final b = OrgContext.fromUser(_user(UserRole.buyer));
      for (final p in [
        '/materials/new',
        '/materials/1/edit',
        '/materials/1/analysis'
      ]) {
        expect(b.canOpen(p), isFalse, reason: p);
      }
      for (final p in ['/', '/materials', '/materials/1', '/organization']) {
        expect(b.canOpen(p), isTrue, reason: p);
      }
    });
  });

  group('GET /auth/me', () {
    Map<String, dynamic> me({
      String kind = 'supplier',
      String role = 'MANAGER',
      List<String> perms = const [
        'material.draft',
        'material.publish',
        'org.read'
      ],
      String activity = 'garment_factory',
      bool membership = true,
    }) =>
        {
          'user': {'id': 'u'},
          'organization': {'id': 'o1', 'kind': kind, 'activity_type': activity},
          'organization_kind': kind,
          'membership': membership
              ? {'organization_id': 'o1', 'role': role, 'status': 'active'}
              : null,
          'default_organization_id': 'o1',
          'permissions': perms,
        };

    test('supplier manager: server permissions are used as is', () {
      final c = OrgContext.fromMe(me());
      expect(c.isSupplier, isTrue);
      expect(c.orgRole, 'MANAGER');
      expect(c.organizationId, 'o1');
      expect(c.can('material.publish'), isTrue);
      expect(c.can(Perm.materialsAnalyze), isFalse); // not in the list
      expect(c.can(Perm.materialsCreate), isTrue);
    });

    test(
        'approved MEMBER rights: planning for supplier, reservation requests for buyer',
        () {
      final supplierMember = OrgContext.fromMe(me(role: 'MEMBER', perms: [
        'material.read',
        'ai.analyze',
        'planning.read',
        'planning.run'
      ]));
      expect(supplierMember.orgRole, 'MEMBER');
      expect(supplierMember.can(Perm.planningRun), isTrue);
      expect(supplierMember.can(Perm.reservationCreate), isFalse);

      final buyerMember = OrgContext.fromMe(me(
          kind: 'buyer',
          role: 'MEMBER',
          perms: ['catalog.read', 'reservation.create', 'reservation.receive'],
          activity: 'garment_factory'));
      expect(buyerMember.can(Perm.reservationCreate), isTrue);
      expect(buyerMember.can(Perm.planningRun), isFalse);
    });

    test('buyer recycler', () {
      final c = OrgContext.fromMe(me(
          kind: 'buyer',
          role: 'OWNER',
          perms: ['catalog.read'],
          activity: 'recycler'));
      expect(c.isSupplier, isFalse);
      expect(c.isRecycler, isTrue);
      expect(c.roleLabel, 'Переработчик');
      expect(c.can(Perm.catalogView), isTrue);
    });

    test('no membership or unknown kind: no permissions, no supplier UI', () {
      final c = OrgContext.fromMe(me(membership: false, kind: 'null'));
      expect(c.permissions, isEmpty);
      expect(c.isSupplier, isFalse);
    });

    testWidgets('the provider serves the server list (API mode)',
        (tester) async {
      final c = ProviderContainer(overrides: [
        orgContextSourceProvider.overrideWithValue(_FakeMe(
            OrgContext.fromMe(me(perms: ['org.read', 'material.read'])))),
      ]);
      addTearDown(c.dispose);
      c.read(sessionProvider.notifier).signIn(
          LoginResult(accessToken: 't', user: _user(UserRole.enterprise)));
      final ctx = await c.read(orgContextProvider.future);
      expect(ctx!.can(Perm.materialsView), isTrue);
      expect(ctx.can(Perm.materialsCreate), isFalse);
      expect(c.read(canProvider(Perm.materialsCreate)), isFalse);
    });
  });

  group('pending_review', () {
    // Shape copied from the live GET /auth/me: lowercase status, no kind, MEMBER role.
    OrgContext pending() => OrgContext.fromMe({
          'organization': {'id': 'o1', 'name': 'ОсОО Тест', 'kind': null},
          'organization_kind': null,
          'membership': {
            'organization_id': 'o1',
            'role': 'MEMBER',
            'status': 'pending_review'
          },
          'default_organization_id': 'o1',
          'permissions': <String>[],
        });

    test('parsed: empty permissions, only the home screen is reachable', () {
      final c = pending();
      expect(c.isPendingReview, isTrue);
      expect(c.permissions, isEmpty);
      expect(c.organizationName, 'ОсОО Тест');
      expect(c.canOpen('/'), isTrue);
      for (final p in ['/materials', '/materials/new', '/organization']) {
        expect(c.canOpen(p), isFalse, reason: p);
      }
      expect(
          authRedirect(
              isAuthenticated: true, location: '/materials', context: c),
          '/');
    });

    Future<ProviderContainer> open(WidgetTester tester) async {
      tester.view.physicalSize = const Size(360, 800);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      final c = ProviderContainer(overrides: [
        appConfigProvider.overrideWithValue(
            const AppConfig(apiBaseUrl: '', useDemoData: false)),
        materialRepositoryProvider.overrideWithValue(RecordingRepo()),
        orgContextSourceProvider.overrideWithValue(_FakeMe(pending())),
      ]);
      addTearDown(c.dispose);
      c.read(sessionProvider.notifier).signIn(
          LoginResult(accessToken: 't', user: _user(UserRole.enterprise)));
      await tester.pumpWidget(
          UncontrolledProviderScope(container: c, child: const ArtaApp()));
      await tester.pumpAndSettle();
      return c;
    }

    testWidgets('review screen instead of the dashboard, no operations',
        (tester) async {
      await open(tester);
      expect(find.text('ОсОО Тест'), findsOneWidget);
      expect(find.text(pendingReviewMessage), findsOneWidget);
      for (final t in [
        'Создать партию',
        'Создать',
        'Опубликовать',
        'Открыть каталог',
        'Здравствуйте,',
        'Доступные партии',
        'Следующий шаг',
      ]) {
        expect(find.text(t), findsNothing, reason: t);
      }
      expect(find.byType(AppFloatingNav), findsNothing);
      expect(find.textContaining('отозв'), findsNothing);
    });

    testWidgets('deep links stay on the review screen; sign-out works',
        (tester) async {
      final c = await open(tester);
      c.read(routerProvider).go('/materials/new');
      await tester.pumpAndSettle();
      expect(find.text(pendingReviewMessage), findsOneWidget);
      expect(find.text('Новая партия'), findsNothing);
      await tester.tap(find.text('Выйти'));
      await tester.pumpAndSettle();
      expect(c.read(sessionProvider).isAuthenticated, isFalse);
      expect(find.text('Вход'), findsOneWidget);
    });
  });

  group('authRedirect with context', () {
    final buyer = OrgContext.fromUser(_user(UserRole.buyer));
    final seller = OrgContext.fromUser(_user(UserRole.enterprise));

    test('role-incompatible route goes home', () {
      expect(
          authRedirect(
              isAuthenticated: true,
              location: '/materials/new',
              context: buyer),
          '/');
      expect(
          authRedirect(
              isAuthenticated: true,
              location: '/materials/new',
              context: seller),
          isNull);
    });

    test('public pages are never role-checked; old calls are unchanged', () {
      for (final p in ['/login', '/register', '/verify-email']) {
        expect(
            authRedirect(isAuthenticated: false, location: p, context: buyer),
            isNull);
      }
      expect(authRedirect(isAuthenticated: true, location: '/materials/new'),
          isNull);
      expect(authRedirect(isAuthenticated: false, location: '/materials/new'),
          '/login');
    });
  });

  testWidgets('buyer typing a supplier route lands home with a message',
      (tester) async {
    final c = await _app(tester, RecordingRepo(), user: _user(UserRole.buyer));
    c.read(routerProvider).go('/materials/new');
    await tester.pumpAndSettle();
    expect(find.text('Новая партия'), findsNothing);
    expect(find.text(roleBlockedMessage), findsOneWidget);
    await tester.tap(find.byTooltip('Закрыть сообщение'));
    await tester.pump();
    expect(find.text(roleBlockedMessage), findsNothing);
  });

  group('home dispatcher', () {
    testWidgets('supplier: own dashboard with create', (tester) async {
      await _app(tester, RecordingRepo(), user: _user(UserRole.enterprise));
      expect(find.text('Роль: Предприятие'), findsOneWidget);
      expect(find.text('Создать партию'), findsOneWidget);
      expect(find.text('Доступные партии'), findsNothing);
    });

    testWidgets('buyer: catalog dashboard, no create', (tester) async {
      await _app(tester, RecordingRepo(), user: _user(UserRole.buyer));
      expect(find.text('Роль: Покупатель'), findsOneWidget);
      expect(find.text('Доступные партии'), findsOneWidget);
      expect(find.text('Создать партию'), findsNothing);
    });

    testWidgets('recycler: buyer dashboard labelled "Переработчик"',
        (tester) async {
      await _app(tester, RecordingRepo(),
          user: _user(UserRole.buyer, email: demoRecyclerEmail), demo: true);
      expect(find.text('Роль: Переработчик'), findsOneWidget);
      expect(find.text('Доступные партии'), findsOneWidget);
      expect(find.text('Создать партию'), findsNothing);
    });

    testWidgets('buyer catalog hides create and filters', (tester) async {
      final c =
          await _app(tester, RecordingRepo(), user: _user(UserRole.buyer));
      c.read(routerProvider).go('/materials');
      await tester.pumpAndSettle();
      expect(find.text('Каталог'), findsWidgets);
      expect(find.text('Создать'), findsNothing);
      expect(find.byType(ChoiceChip), findsNothing);
    });
  });

  testWidgets('sign-out resets the organization context and notices',
      (tester) async {
    final c =
        await _app(tester, RecordingRepo(), user: _user(UserRole.enterprise));
    expect(c.read(orgContextProvider).valueOrNull?.isSupplier, isTrue);
    c.read(routeNoticeProvider.notifier).state = 'x';
    c.read(sessionProvider.notifier).signOut();
    await tester.pumpAndSettle();
    expect(c.read(orgContextProvider).valueOrNull, isNull);
    expect(c.read(routeNoticeProvider), isNull);
    expect(find.text('Вход'), findsOneWidget);
    // The next user gets their own context, not the previous one.
    c
        .read(sessionProvider.notifier)
        .signIn(LoginResult(accessToken: 't2', user: _user(UserRole.buyer)));
    await tester.pumpAndSettle();
    expect(c.read(orgContextProvider).valueOrNull?.isSupplier, isFalse);
  });

  group('demo accounts', () {
    test('buyer and recycler sign in; no demo admin; wrong password fails',
        () async {
      final repo = DemoAuthRepository();
      final b =
          await repo.login(email: demoBuyerEmail, password: demoBuyerPassword);
      expect(b.user.role, UserRole.buyer);
      final r = await repo.login(
          email: demoRecyclerEmail, password: demoRecyclerPassword);
      expect(r.user.role, UserRole.buyer);
      expect(r.user.organizationId, isNot(b.user.organizationId));
      expect(demoOrganizationFor(demoRecyclerEmail).activityType,
          ActivityType.recycler);
      expect(demoOrganizationFor(demoBuyerEmail).activityType,
          ActivityType.workshop);
      await expectLater(repo.login(email: demoBuyerEmail, password: 'nope'),
          throwsA(isA<ApiException>()));
      await expectLater(
          repo.login(email: 'admin@demo.arta', password: 'demo-admin-1'),
          throwsA(isA<ApiException>()));
    });

    test('buyer demo sees published batches only, without the owner balance',
        () async {
      final seller = DemoMaterialRepository();
      final all = (await seller.list()).items;
      expect(all.any((m) => m.status == MaterialStatus.draft), isTrue);
      final buyer = DemoMaterialRepository(publicView: true);
      final seen = (await buyer.list()).items;
      expect(seen, isNotEmpty);
      expect(
          seen.every((m) =>
              m.status == MaterialStatus.available ||
              m.status == MaterialStatus.partiallyAllocated),
          isTrue);
      expect(seen.every((m) => !m.isOwnerView), isTrue);
      final draft = all.firstWhere((m) => m.status == MaterialStatus.draft);
      await expectLater(buyer.get(draft.id), throwsA(isA<ApiException>()));
    });
  });

  group('403 and 404 messages', () {
    Widget host(ApiException e) =>
        MaterialApp(home: Scaffold(body: ErrorBanner(error: e)));

    testWidgets('403 keeps the server text and shows the request id',
        (tester) async {
      await tester.pumpWidget(host(const ApiException(
          code: 'FORBIDDEN',
          message: 'Недостаточно прав.',
          statusCode: 403,
          requestId: 'req-9')));
      expect(find.text('Недостаточно прав.'), findsOneWidget);
      expect(find.text('Код обращения: req-9'), findsOneWidget);
    });

    testWidgets('404 shows the server message, without a request id',
        (tester) async {
      await tester.pumpWidget(host(const ApiException(
          code: 'NOT_FOUND',
          message: 'Объект не найден.',
          statusCode: 404,
          requestId: 'r')));
      expect(find.text('Объект не найден.'), findsOneWidget);
      expect(find.textContaining('Код обращения'), findsNothing);
    });
  });
}
