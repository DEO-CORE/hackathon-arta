import 'dart:async';

import 'package:arta/core/network/api_exception.dart';
import 'package:arta/core/session/org_context.dart';
import 'package:arta/core/session/session.dart';
import 'package:arta/features/auth/models/auth_models.dart';
import 'package:arta/features/auth/providers/org_context_provider.dart';
import 'package:arta/features/materials/models/catalog_filter.dart';
import 'package:arta/features/materials/models/material_enums.dart';
import 'package:arta/features/materials/presentation/catalog_screen.dart';
import 'package:arta/features/materials/providers/material_providers.dart';
import 'package:arta/features/reservations/data/reservation_repository.dart';
import 'package:arta/features/reservations/models/reservation_models.dart';
import 'package:arta/features/reservations/presentation/reserve_sheet.dart';
import 'package:arta/features/reservations/presentation/reservations_screen.dart';
import 'package:arta/features/reservations/providers/reservation_providers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/material_fakes.dart';

Reservation res(String id, ReservationStatus st,
        {String qty = '40.000', String? buyer = 'Мастерская Алтын'}) =>
    Reservation(
      id: id,
      materialId: 'm1',
      materialName: 'Хлопок $id',
      quantityKg: qty,
      status: st,
      buyerOrganizationName: buyer,
      sellerOrganizationName: 'Фабрика',
      agreedPricePerKg: '120.00',
    );

class FakeResRepo implements ReservationRepository {
  List<Reservation> items = [];
  ApiException? listError;
  ApiException? actError;
  ApiException? createError;
  Completer<Reservation>? createGate;
  final created = <ReservationRequest>[];
  final acts = <Map<String, Object?>>[];
  int listCalls = 0;
  List<ReservationStatus>? lastStatuses;

  @override
  Future<ReservationPage> list(
      {List<ReservationStatus>? statuses,
      int page = 1,
      int pageSize = 20}) async {
    listCalls++;
    lastStatuses = statuses;
    if (listError != null) throw listError!;
    final src = items.where((r) => statuses!.contains(r.status)).toList();
    return ReservationPage(items: src, page: 1, total: src.length);
  }

  @override
  Future<Reservation> create(ReservationRequest request) {
    created.add(request);
    if (createGate != null) return createGate!.future;
    if (createError != null) return Future.error(createError!);
    return Future.value(res('new', ReservationStatus.pending));
  }

  @override
  Future<Reservation> act(String id, ReservationAction action,
      {String? reason, String? transferredKg, String? idempotencyKey}) async {
    acts.add({
      'id': id,
      'action': action.api,
      'reason': reason,
      'kg': transferredKg
    });
    if (actError != null) throw actError!;
    return res(id, ReservationStatus.confirmed);
  }

  @override
  Future<TransactionPage> transactions(
          {int page = 1, int pageSize = 20}) async =>
      const TransactionPage(items: [], page: 1, total: 0);
}

class _Me implements OrgContextSource {
  _Me(this.ctx);
  final OrgContext ctx;
  @override
  Future<OrgContext> load(AuthUser user) async => ctx;
}

OrgContext ctx(OrgType type, Set<String> perms) => OrgContext(
    organizationId: 'o', orgType: type, orgRole: 'OWNER', permissions: perms);

const supplierPerms = {
  Perm.reservationRead,
  Perm.reservationApprove,
  Perm.materialsView
};
const buyerPerms = {
  Perm.reservationRead,
  Perm.reservationCreate,
  Perm.reservationReceive,
  Perm.catalogView
};

ProviderContainer mk(FakeResRepo repo, OrgContext c,
    {RecordingRepo? materials}) {
  final supplier = c.isSupplier;
  final container = ProviderContainer(overrides: [
    reservationRepositoryProvider.overrideWithValue(repo),
    materialRepositoryProvider.overrideWithValue(materials ?? RecordingRepo()),
    orgContextSourceProvider.overrideWithValue(_Me(c)),
  ]);
  addTearDown(container.dispose);
  container.read(sessionProvider.notifier).signIn(LoginResult(
        accessToken: 't',
        user: AuthUser(
            id: 'u',
            email: 'e@x.test',
            role: supplier ? UserRole.enterprise : UserRole.buyer,
            organizationId: 'o',
            active: true),
      ));
  return container;
}

void main() {
  group('ReserveController payload and idempotency', () {
    test('retry after an error reuses the key; new quantity gets a new key',
        () async {
      final repo = FakeResRepo()
        ..createError =
            const ApiException(code: 'NETWORK_ERROR', message: 'сеть');
      final c = mk(repo, ctx(OrgType.buyer, buyerPerms));
      final n = c.read(reserveProvider('m1').notifier);
      expect(await n.submit(quantityKg: '12,5'), isFalse);
      expect(await n.submit(quantityKg: '12,5'), isFalse);
      expect(repo.created[0].idempotencyKey, repo.created[1].idempotencyKey);
      expect(repo.created[0].toJson(),
          {'material_id': 'm1', 'quantity_kg': '12.5'});
      await n.submit(quantityKg: '13');
      expect(repo.created[2].idempotencyKey,
          isNot(repo.created[0].idempotencyKey));
      // After success the next intent starts with a fresh key.
      repo.createError = null;
      await n.submit(quantityKg: '13');
      final okKey = repo.created[3].idempotencyKey;
      await n.submit(quantityKg: '13');
      expect(repo.created[4].idempotencyKey, isNot(okKey));
      expect(RegExp(r'^[A-Za-z0-9_-]{8,128}$').hasMatch(okKey), isTrue);
    });

    test('second submit while in flight is ignored', () async {
      final repo = FakeResRepo()..createGate = Completer();
      final c = mk(repo, ctx(OrgType.buyer, buyerPerms));
      final n = c.read(reserveProvider('m1').notifier);
      final first = n.submit(quantityKg: '5');
      expect(await n.submit(quantityKg: '5'), isFalse);
      expect(repo.created, hasLength(1));
      repo.createGate!.complete(res('x', ReservationStatus.pending));
      expect(await first, isTrue);
    });
  });

  group('validateRequestKg', () {
    test('rules', () {
      expect(validateRequestKg('', '10.000'), isNotNull);
      expect(validateRequestKg('0', '10.000'), isNotNull);
      expect(validateRequestKg('abc', '10.000'), isNotNull);
      expect(validateRequestKg('1.2345', '10.000'), isNotNull);
      expect(validateRequestKg('10,001', '10.000'), contains('Доступно'));
      expect(validateRequestKg('10,000', '10.000'), isNull);
    });
  });

  group('supplier screen', () {
    Future<void> open(WidgetTester tester, ProviderContainer c) =>
        pumpScreen(tester, c, const ReservationsScreen());

    testWidgets('shows buyer, quantity, price and approve/reject for pending',
        (tester) async {
      final repo = FakeResRepo()..items = [res('a', ReservationStatus.pending)];
      final c = mk(repo, ctx(OrgType.supplier, supplierPerms));
      await open(tester, c);
      await tester.pumpAndSettle();
      expect(find.text('Хлопок a'), findsOneWidget);
      expect(find.textContaining('Мастерская Алтын'), findsOneWidget);
      expect(find.textContaining('Запрошено: 40\u00A0кг'), findsOneWidget);
      expect(find.textContaining('120\u00A0KGS/кг'), findsOneWidget);
      expect(find.text('Подтвердить резерв'), findsOneWidget);
      expect(find.text('Отклонить'), findsOneWidget);
    });

    testWidgets('no approval permission: action buttons are hidden',
        (tester) async {
      final repo = FakeResRepo()..items = [res('a', ReservationStatus.pending)];
      final c = mk(repo, ctx(OrgType.supplier, const {Perm.reservationRead}));
      await open(tester, c);
      await tester.pumpAndSettle();
      expect(find.text('Подтвердить резерв'), findsNothing);
      expect(find.text('Отклонить'), findsNothing);
    });

    testWidgets('approve sends confirm and reloads', (tester) async {
      final repo = FakeResRepo()..items = [res('a', ReservationStatus.pending)];
      final c = mk(repo, ctx(OrgType.supplier, supplierPerms));
      await open(tester, c);
      await tester.pumpAndSettle();
      final before = repo.listCalls;
      await tester.tap(find.text('Подтвердить резерв'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Подтвердить резерв').last);
      await tester.pumpAndSettle();
      expect(repo.acts.single['action'], 'confirm');
      expect(repo.listCalls, greaterThan(before));
    });

    testWidgets('409 shows the server message', (tester) async {
      final repo = FakeResRepo()
        ..items = [res('a', ReservationStatus.pending)]
        ..actError = const ApiException(
            code: 'PRECONDITION_FAILED',
            message: 'Свободной массы стало меньше.',
            statusCode: 409);
      final c = mk(repo, ctx(OrgType.supplier, supplierPerms));
      await open(tester, c);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Подтвердить резерв'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Подтвердить резерв').last);
      await tester.pumpAndSettle();
      expect(find.text('Свободной массы стало меньше.'), findsOneWidget);
    });

    testWidgets('reject needs a reason and sends it', (tester) async {
      final repo = FakeResRepo()..items = [res('a', ReservationStatus.pending)];
      final c = mk(repo, ctx(OrgType.supplier, supplierPerms));
      await open(tester, c);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Отклонить'));
      await tester.pumpAndSettle();
      FilledButton submit() => tester.widget<FilledButton>(
          find.widgetWithText(FilledButton, 'Отклонить заявку'));
      expect(submit().onPressed, isNull);
      await tester.enterText(find.byType(TextFormField), '   ');
      await tester.pump();
      expect(submit().onPressed, isNull);
      await tester.enterText(find.byType(TextFormField), 'Нет остатка');
      await tester.pump();
      await tester.tap(find.widgetWithText(FilledButton, 'Отклонить заявку'));
      await tester.pumpAndSettle();
      expect(repo.acts.single,
          {'id': 'a', 'action': 'cancel', 'reason': 'Нет остатка', 'kg': null});
    });

    testWidgets('transfer: empty field sends no quantity; too much is blocked',
        (tester) async {
      final repo = FakeResRepo()
        ..items = [res('a', ReservationStatus.confirmed)];
      final c = mk(repo, ctx(OrgType.supplier, supplierPerms));
      await open(tester, c);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Отметить передачу'));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextFormField), '41');
      await tester.pump();
      expect(find.textContaining('Нельзя передать больше удержанного'),
          findsOneWidget);
      await tester.enterText(find.byType(TextFormField), '');
      await tester.pump();
      await tester.tap(find.text('Подтвердить передачу'));
      await tester.pumpAndSettle();
      expect(repo.acts.single['action'], 'transfer');
      expect(repo.acts.single['kg'], isNull);
    });

    testWidgets('empty and error states', (tester) async {
      final repo = FakeResRepo();
      final c = mk(repo, ctx(OrgType.supplier, supplierPerms));
      await open(tester, c);
      await tester.pumpAndSettle();
      expect(find.text('Пока нет входящих заявок.'), findsOneWidget);
    });

    testWidgets('error state offers retry', (tester) async {
      final repo2 = FakeResRepo()
        ..listError = const ApiException(
            code: 'X', message: 'Сервер недоступен', statusCode: 500);
      final c2 = mk(repo2, ctx(OrgType.supplier, supplierPerms));
      await open(tester, c2);
      await tester.pumpAndSettle();
      expect(find.text('Сервер недоступен'), findsOneWidget);
      expect(find.text('Повторить'), findsOneWidget);
    });
  });

  group('buyer screen', () {
    testWidgets('transferred: confirm receipt; pending: cancel',
        (tester) async {
      final repo = FakeResRepo()
        ..items = [
          res('t', ReservationStatus.transferred),
          res('p', ReservationStatus.pending),
        ];
      final c = mk(repo, ctx(OrgType.buyer, buyerPerms));
      await pumpScreen(tester, c, const ReservationsScreen());
      await tester.pumpAndSettle();
      expect(find.text('Заявки'), findsWidgets);
      expect(find.text('Отклонить'), findsNothing);
      await tester.tap(find.text('Подтвердить получение'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Подтвердить получение').last);
      await tester.pumpAndSettle();
      expect(repo.acts.single['action'], 'complete');
      expect(find.text('Отменить заявку'), findsOneWidget);
    });

    testWidgets('empty state leads to the catalog', (tester) async {
      final c = mk(FakeResRepo(), ctx(OrgType.buyer, buyerPerms));
      await pumpScreen(tester, c, const ReservationsScreen());
      await tester.pumpAndSettle();
      expect(find.text('У вас пока нет активных заявок.'), findsOneWidget);
      expect(find.text('Открыть каталог'), findsOneWidget);
    });
  });

  group('reserve sheet', () {
    Future<FakeResRepo> openSheet(WidgetTester tester,
        {FakeResRepo? repo}) async {
      repo ??= FakeResRepo();
      final c = mk(repo, ctx(OrgType.buyer, buyerPerms));
      await pumpScreen(
          tester,
          c,
          Builder(
              builder: (ctx) => Scaffold(
                    body: TextButton(
                        onPressed: () => showReserveSheet(ctx,
                            fakeItem('m1', status: MaterialStatus.available)),
                        child: const Text('open')),
                  )));
      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();
      return repo;
    }

    testWidgets('validates > 0 and <= available, shows kg', (tester) async {
      await openSheet(tester);
      expect(find.text('Свободно сейчас: 10\u00A0кг'), findsOneWidget);
      await tester.tap(find.text('Продолжить'));
      await tester.pumpAndSettle();
      expect(find.text('Укажите массу'), findsOneWidget);
      await tester.enterText(find.byType(TextFormField), '11');
      await tester.tap(find.text('Продолжить'));
      await tester.pumpAndSettle();
      expect(
          find.textContaining('Доступно не более 10\u00A0кг'), findsOneWidget);
    });

    testWidgets(
        'sends one request, blocks a second tap, keeps the key on retry',
        (tester) async {
      final repo = FakeResRepo()..createGate = Completer();
      await openSheet(tester, repo: repo);
      await tester.enterText(find.byType(TextFormField), '2,5');
      await tester.tap(find.text('Продолжить'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Отправить заявку'));
      await tester.pump();
      expect(find.text('Отправка…'), findsOneWidget);
      await tester.tap(find.text('Отправка…'), warnIfMissed: false);
      await tester.pump();
      expect(repo.created, hasLength(1));
      expect(repo.created.single.quantityKg, '2.5');
      repo.createGate!.completeError(const ApiException(
          code: 'PRECONDITION_FAILED',
          message: 'Свободного количества стало меньше.',
          statusCode: 409));
      await tester.pumpAndSettle();
      expect(find.text('Свободного количества стало меньше.'), findsOneWidget);
      repo.createGate = null;
      repo.createError = const ApiException(code: 'X', message: 'e');
      await tester.tap(find.text('Отправить заявку'));
      await tester.pumpAndSettle();
      expect(repo.created, hasLength(2));
      expect(repo.created[1].idempotencyKey, repo.created[0].idempotencyKey);
    });
  });

  group('buyer catalog filters', () {
    testWidgets('search and type filter go to the repository', (tester) async {
      final materials = RecordingRepo();
      final c = mk(FakeResRepo(), ctx(OrgType.buyer, buyerPerms),
          materials: materials);
      await pumpScreen(tester, c, const CatalogScreen());
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextFormField).first, 'хлопок');
      await tester.testTextInput.receiveAction(TextInputAction.search);
      await tester.pumpAndSettle();
      expect(materials.lastFilter.q, 'хлопок');
      await tester.tap(find.text('Фильтры'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Хлопок'));
      await tester.pump();
      await tester.tap(find.text('Применить'));
      await tester.pumpAndSettle();
      expect(materials.lastFilter.type, TextileType.cotton);
      expect(materials.lastFilter.toQuery()['material_type'], ['cotton']);
      expect(find.textContaining('Фильтры (1)'), findsOneWidget);
    });

    test('filter query', () {
      const f = CatalogFilter(minAvailableKg: '5,5', city: ' Бишкек ');
      expect(f.toQuery(), {'city': 'Бишкек', 'min_available_kg': '5.5'});
    });
  });
}
