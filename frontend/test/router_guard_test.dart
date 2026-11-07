import 'package:arta/app/app.dart';
import 'package:arta/app/router.dart';
import 'package:arta/core/session/session.dart';
import 'package:arta/features/auth/models/auth_models.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

const _login = LoginResult(
  accessToken: 't',
  user: AuthUser(
    id: '1',
    email: 'a@b.kg',
    role: UserRole.enterprise,
    organizationId: '2',
    active: true,
  ),
);

void main() {
  group('authRedirect', () {
    test('sends anonymous users to /login', () {
      expect(authRedirect(isAuthenticated: false, location: '/'), '/login');
      expect(
        authRedirect(isAuthenticated: false, location: '/organization'),
        '/login',
      );
    });

    test('keeps anonymous users on public pages', () {
      expect(authRedirect(isAuthenticated: false, location: '/login'), isNull);
      expect(
        authRedirect(isAuthenticated: false, location: '/register'),
        isNull,
      );
    });

    test('sends authenticated users away from auth pages', () {
      expect(authRedirect(isAuthenticated: true, location: '/login'), '/');
      expect(authRedirect(isAuthenticated: true, location: '/register'), '/');
      expect(authRedirect(isAuthenticated: true, location: '/'), isNull);
    });
  });

  testWidgets('router follows session state', (tester) async {
    final container = ProviderContainer();
    addTearDown(container.dispose);
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const ArtaApp(),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Вход'), findsOneWidget);

    container.read(sessionProvider.notifier).signIn(_login);
    await tester.pumpAndSettle();
    expect(find.text('Роль: Предприятие'), findsOneWidget);

    container.read(sessionProvider.notifier).expire();
    await tester.pumpAndSettle();
    expect(find.text('Вход'), findsOneWidget);
    expect(find.text('Сессия истекла. Войдите снова.'), findsOneWidget);
  });
}
