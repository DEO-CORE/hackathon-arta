import 'package:arta/features/auth/models/auth_models.dart';
import 'package:arta/features/auth/providers/org_context_provider.dart';
import 'package:arta/features/profile/data/organization_repository.dart';
import 'package:arta/features/profile/models/organization.dart';
import 'package:arta/features/profile/presentation/organization_screen.dart';
import 'package:arta/features/profile/providers/organization_providers.dart';
import 'package:arta/core/session/session.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/material_fakes.dart';

class _FakeOrgRepo implements OrganizationRepository {
  _FakeOrgRepo(this.org);
  Organization org;
  OrganizationPatch? lastPatch;

  @override
  Future<Organization> getMe() async => org;

  @override
  Future<Organization> patchMe(OrganizationPatch patch) async {
    lastPatch = patch;
    org = org.copyWith(
      name: patch.name,
      city: patch.city,
      activityType: patch.activityType,
      contacts: patch.contacts,
    );
    return org;
  }
}

const _org = Organization(
  id: 'o',
  name: 'Швейная фабрика',
  city: 'Бишкек',
  activityType: ActivityType.garmentFactory,
  contacts: Contacts(
      name: 'Айбек', phone: '+996 555 000 111', email: 'ops@example.test'),
);

ProviderContainer _container(_FakeOrgRepo repo, UserRole role) {
  final container = ProviderContainer(overrides: [
    organizationRepositoryProvider.overrideWithValue(repo),
    orgContextSourceProvider.overrideWithValue(FixtureOrgContextSource()),
  ]);
  addTearDown(container.dispose);
  container.read(sessionProvider.notifier).signIn(LoginResult(
        accessToken: 't',
        user: AuthUser(
            id: 'u',
            email: 'e@x.test',
            role: role,
            organizationId: 'o',
            active: true),
      ));
  return container;
}

void main() {
  testWidgets(
      'supplier profile: monogram, kind badge and supplier capabilities',
      (tester) async {
    final container = _container(_FakeOrgRepo(_org), UserRole.enterprise);
    await pumpScreen(tester, container, const OrganizationScreen());
    await tester.pumpAndSettle();

    expect(find.text('ШФ'), findsOneWidget); // monogram from the name
    expect(find.text('Швейная фабрика'), findsWidgets);
    expect(find.text('Предприятие'), findsWidgets);
    expect(find.text('Партии: черновики, фото и публикация'), findsOneWidget);
    expect(find.text('Каталог опубликованных партий'), findsNothing);
    expect(find.text('Изменить'), findsNWidgets(2));
  });

  testWidgets('buyer profile shows buyer capabilities, not supplier ones',
      (tester) async {
    final container = _container(
        _FakeOrgRepo(_org.copyWith(activityType: ActivityType.workshop)),
        UserRole.buyer);
    await pumpScreen(tester, container, const OrganizationScreen());
    await tester.pumpAndSettle();

    expect(find.text('Покупатель'), findsWidgets);
    expect(find.text('Каталог опубликованных партий'), findsOneWidget);
    expect(find.text('Партии: черновики, фото и публикация'), findsNothing);
  });

  testWidgets('org edit sheet saves and keeps the contacts untouched',
      (tester) async {
    final repo = _FakeOrgRepo(_org);
    final container = _container(repo, UserRole.enterprise);
    await pumpScreen(tester, container, const OrganizationScreen());
    await tester.pumpAndSettle();

    await tester.tap(find.text('Изменить').first);
    await tester.pumpAndSettle();
    expect(find.text('Данные организации'), findsOneWidget);

    await tester.enterText(find.widgetWithText(TextFormField, 'Город'), 'Ош');
    await tester.tap(find.text('Сохранить'));
    await tester.pumpAndSettle();

    expect(repo.lastPatch?.city, 'Ош');
    expect(repo.lastPatch?.contacts?.phone, '+996 555 000 111');
    expect(repo.lastPatch?.contacts?.email, 'ops@example.test');
    expect(find.text('Данные организации'), findsNothing);
  });
}
