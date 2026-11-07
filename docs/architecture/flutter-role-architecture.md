# Архитектура Flutter для мультиролевого режима ARTA

Статус: план, реализация не начата. Код `frontend/lib` этим документом не меняется.
Источник истины по ролям, правам и членству - сервер. Клиент только показывает.

## 0. Текущее состояние (по коду)

Сессия (`core/session/session.dart`)
- `SessionState{token, user: AuthUser, expired}`; `isAuthenticated = token != null && user != null`.
- Токен только в памяти (перезагрузка = новый вход). `signIn/signOut/expire`.
- `AuthUser{id, email, role: UserRole{enterprise,buyer,admin}, organizationId, active}`. Одна роль, одна организация на пользователя (упрощение MVP из CLAUDE.md). `UserRole.parse` при неизвестном значении молча даёт `buyer` - это надо поменять (см. риски).
- `ApiClient.onUnauthorized` -> `sessionProvider.expire()` только при `UNAUTHENTICATED`; `INVALID_CREDENTIALS` сессию не рвёт.

Маршруты (`app/router.dart`)
- `authRedirect({isAuthenticated, location})` - чистая функция; публичные `/login`, `/register`, `/verify-email`; авторизованного с публичных путей кидает на `/`.
- Плоский `GoRouter` без `ShellRoute`; `refreshListenable` дергается от `sessionProvider`. Маршруты: `/`, `/materials`, `/materials/new`, `/materials/:id`, `/materials/:id/edit`, `/materials/:id/analysis`, `/organization`.
- Роль в guard не участвует: `/materials/new` доступен buyer на уровне роутера (защита - только сервер).
- `AppTabShell` - обычный виджет, не ShellRoute; три вкладки (`home/materials/organization`), роль читается из `sessionProvider.user.role` и влияет только на подпись («Партии»/«Каталог»). Навигация через `context.go`, `tabBack` для стрелки.

Организация (`features/profile`)
- `Organization{id,name,city,activityType,contacts}`; `organizationProvider` (FutureProvider.autoDispose -> `GET /organizations/me`), `PATCH /organizations/me`. Членств, ролей внутри организации, прав - нет.

Провайдеры и демо
- Паттерн репозиториев: abstract interface + `Api*Repository(ApiClient)` + `Demo*Repository`; выбор в `Provider` по `appConfigProvider.useDemoData` (`--dart-define=USE_DEMO_DATA=true`), без fallback при ошибках сети. Так сделаны auth, email verification, organization, material.
- Демо: `DemoAuthRepository` (единственный сид `seller@demo.arta`, роль enterprise), `DemoMaterialRepository` + `DemoStore` (файловое/память), `DemoBanner` в `ArtaApp.builder`, `demo_reset_section`.
- Состояния: `AsyncValue` для чтения, Notifier-контроллеры со `submitting/busy` для записи, `ApiException` (code, statusCode, details, requestId) везде.
- `HomeScreen` одна для обеих ролей, ветвление `isEnterprise` внутри экрана; `catalogProvider` общий.

## 1. Role-aware routing

Принцип: guard остаётся чистой функцией, расширяется обратно-совместимо.

```dart
String? authRedirect({
  required bool isAuthenticated,
  required String location,
  // новые, необязательные - старые вызовы и тесты не ломаются
  OrgContextStatus? context,   // loading / ready / noOrganization / error
  RoleView? role,              // enterprise | buyer | admin | null
})
```

Порядок решений:
1. Публичные пути и неавторизованный - как сейчас (`/login`, `/register`, `/verify-email` всегда без проверки роли и контекста).
2. Авторизован, контекст `loading` - не редиректить, показать экран ожидания внутри shell (не отдельный маршрут, чтобы не мигать URL).
3. Контекст `noOrganization` (членство отозвано/нет активной организации) -> `/no-organization` (новый, единственный новый обязательный маршрут).
4. Роль-несовместимый маршрут -> `/` (не `/login`) плюс одноразовое уведомление «Раздел недоступен для вашей роли». Таблица `routeRoles` (префикс -> допустимые роли) лежит рядом с router; пример: `/materials/new`, `/materials/:id/edit`, `/materials/:id/analysis` - enterprise; `/admin/*` - admin; остальное - все.
5. Admin в продуктовых маршрутах: `/` для admin = экран модерации (см. 4), без демо.

Что не меняем: пути существующих маршрутов, плоскую структуру, `AppTabShell` как виджет. Новые маршруты добавляются, старые остаются: `/requirements`, `/reservations`, `/reservations/:id`, `/team` (членство, приглашения), `/invitations/accept` (публичный? нет - только после входа; токен приглашения идёт query-параметром и сохраняется до входа через `pendingInvitationProvider`), `/moderation`, `/no-organization`.

`refreshListenable` слушает и сессию, и `orgContextProvider`. Guard - UX, не безопасность (см. п. 3).

## 2. Organization context provider

Состав `OrgContext` (immutable):
- `activeOrganization: Organization` (id, name, city, activityType, contacts),
- `memberships: List<Membership>` (organizationId, orgName, role, status),
- `activeMembership` (организация + `roleInOrg`: owner / manager / member - уточнить у backend; сейчас на сервере есть только `enterprise|buyer|admin` на пользователе),
- `permissions: Set<Permission>` - только то, что пришло с сервера (`can_publish`, `can_confirm_reservation`, ...). Клиент не выводит права из роли сам, кроме fallback-а на текущий контракт.

Источник:
- Сегодня: `GET /organizations/me` + `AuthUser.role` из логина. Адаптер `OrgContextRepository.load()` собирает контекст из них: одно членство, права = `null` (неизвестно).
- Будущее (нужен контракт от оркестратора, не придумываем): `GET /organizations/me` с `role_in_org` и `permissions`, `GET /memberships/me`, `POST /memberships/active` (смена активной организации). До появления - только интерфейс и демо-реализация.

Провайдер: `orgContextProvider = AsyncNotifierProvider<OrgContextController, OrgContext>`, `ref.watch(sessionProvider.select((s) => s.user?.id))` в `build` - при смене пользователя перестраивается. Не autoDispose (нужен роутеру).

Сброс:
- Выход/`expire`: контекст инвалидируется через зависимость от session; дополнительно единая функция `resetUserScopedState(ref)` инвалидирует все user-scoped провайдеры (catalog, reservations, requirements, organization, analysis). Сейчас autoDispose-провайдеры сами не сбрасываются, пока на них кто-то подписан, поэтому явный список обязателен (тест: выход -> вход другим пользователем не показывает чужих данных).
- Смена роли/членства на сервере: клиент узнаёт только по ответу (403 `ROLE_CHANGED`/`MEMBERSHIP_REVOKED` или 401). Обработка: на любой такой код `ApiClient` вызывает `onContextStale` -> `orgContextProvider.refresh()`; если роль изменилась - навигация на `/` и сообщение. Опционально refresh при возврате приложения на передний план и раз в N минут (не polling-шторм).
- Токен несёт старую роль: после смены роли сервер должен либо отзывать токен (401), либо проверять роль по БД на каждый запрос. Клиент полагается на второе.

## 3. Permission-aware виджеты

- `ref.watch(permissionsProvider)` -> `Can(permission, child, fallback)` / `context.can(...)`. Используется только для показа: скрыть, отключить с пояснением («Нужна роль владельца»), не показывать неработающие CTA (требование CLAUDE.md).
- Это не защита: сервер проверяет роль, организацию и владение на каждом запросе. Скрытая кнопка не мешает прямому URL или устаревшему состоянию. Поэтому действие всегда отправляется на сервер, даже если `can == false` в UI-слое не гарантируется (UI просто не предлагает).
- Единая обработка ошибок авторизации в `core/network` (расширение `ApiException`): `isForbidden` (403, code `FORBIDDEN`), `isNotFound` (404 - для скрытых объектов не отличать от отсутствия), `isConflict` (409). 
  - 403: показать `ErrorPanel` с сообщением сервера и requestId, кнопка «Обновить права» (refresh контекста). Не редиректить автоматически и не прятать ошибку.
  - 404 на карточке: «Объект не найден или недоступен» (не раскрывать причину), вернуть к списку.
  - 409: как сейчас (VERSION_CONFLICT и т.д.), экран показывает остаток/конфликт; для резервов - `INSUFFICIENT_STOCK` и т.п.
- Тест на каждый защищённый экран: сервер отдаёт 403 при `can == true` (устаревший контекст) - ошибка видна пользователю.

## 4. Dashboards и bottom navigation

Общее (один код): каталог/карточка партии (режимы по роли внутри), профиль организации, список резервов (фильтр по стороне задаёт сервер), `ErrorPanel`/`AppStates`, UI-kit `core/ui`.

Отдельное:
| Роль | Home | Вкладки |
|---|---|---|
| enterprise | `EnterpriseDashboard`: черновики, остатки, ожидающие заявки, план | Главная, Партии, Заявки, Организация |
| buyer (и recycler) | `BuyerDashboard`: потребности, мои заявки, подходящие партии | Главная, Каталог, Потребности/Заявки, Организация |
| admin | `ModerationHome`: очередь модерации | Модерация, Организации (без каталога продавца/покупателя) |

Как не дублировать:
- `HomeScreen` превращается в тонкий диспетчер: `switch (role) -> EnterpriseDashboard | BuyerDashboard | ModerationHome`; существующая логика enterprise переезжает в `EnterpriseDashboard` без изменений поведения (виджеты и ключи сохраняем ради тестов).
- Вкладки: `AppTab` остаётся, `AppTabShell` берёт `List<AppNavItem>` из `navItemsFor(role)` (чистая функция, тестируется). `AppTab.index` привязан к позиции - заменить на `route`-based выбор, но сохранить enum-значения для старых экранов (`home, materials, organization` не переименовывать; добавить `reservations`, `requirements`, `moderation`).
- Виджеты-карточки метрик/списков параметризуются данными, не ролью.

## 5. Репозитории

По шаблону проекта: `abstract class XRepository` + `ApiXRepository(ApiClient)` + `DemoXRepository`, провайдер выбирает по `useDemoData`.

| Репозиторий | Методы (черновик) | Эндпоинты | Состояние контракта |
|---|---|---|---|
| `OrgContextRepository` | `load()`, `switchActive(orgId)` | `/organizations/me` (+ будущие) | частично |
| `MembershipRepository` | `list()`, `updateRole()`, `remove()` | не в api.md | нужен контракт |
| `InvitationRepository` | `create(email, role)`, `list()`, `revoke()`, `accept(token)` | не в api.md | нужен контракт |
| `BuyerRequirementRepository` | `list()`, `create()`, `patch()` | `/buyer-requirements` (есть) | есть |
| `ReservationRepository` | `list()`, `create(idempotencyKey)`, `action(confirm/cancel/transfer/complete)` | `/reservations`, `PATCH /reservations/{id}` | есть в api.md |
| `TransferRepository` | `confirmReuse(transactionId)` | `/transactions/{id}/reuse-confirmation` | есть |
| `ModerationRepository` | `queue()`, `decide()` | не в api.md | нужен контракт |

Правила: DTO immutable; Decimal-строки для кг/KGS (не double); idempotency key генерируется один раз на намерение и переживает повтор; модерация/членство/приглашения реализуются сначала как интерфейс + демо, Api-реализация только после появления контракта (не изобретаем пути). Общий `ApiClient` и `apiCall` без изменений.

## 6. Состояния и демо-режим по ролям

Состояния: каждый экран - loading / empty / error / success; формы блокируют второй submit (`busy`-флаг, как в `LifecycleController`). Для контекста: `OrgContextStatus.loading` не блокирует публичные экраны; `error` показывает повтор, а не выкидывает на логин.

Демо:
- Включение только `USE_DEMO_DATA=true` (как сейчас), баннер «Демо» остаётся, без тихого переключения и без fallback при ошибках сети.
- Сиды по ролям: `seller@demo.arta` (enterprise), `buyer@demo.arta` (buyer), `recycler@demo.arta` (buyer + recycler). Вход - обычный экран логина, пользователь сам выбирает учётку (подсказка с демо-данными на экране входа показывает все три). Никакого «переключателя роли» без повторного входа.
- Демо-админа не создаём: `DemoAuthRepository` отвергает `admin`; `ModerationHome` в демо-сборке недоступен, маршрут `/moderation` -> `/` в демо. Тест это фиксирует.
- Демо-хранилище на роль/организацию раздельно (ключи в `DemoStore` включают organizationId), чтобы покупатель не видел черновиков продавца; общий опубликованный каталог читается из одного сида. Синтетические данные помечены «демо».
- Реальный `ApiXRepository` никогда не создаётся при `useDemoData`, и наоборот (проверяется `demo_isolation_test`).

## 7. Риски

Сломать существующие тесты (файлы, затрагивающие session/router/shell/роль):
- `router_guard_test.dart` - сигнатура `authRedirect` (новые параметры необязательные, поведение по умолчанию прежнее).
- `tab_navigation_test.dart`, `material_navigation_test.dart` - `AppTabShell`, число и порядок вкладок (добавление вкладки «Заявки» поменяет индексы).
- `home_dashboard_test.dart` - вынос ветки enterprise в отдельный виджет; ключи и тексты сохранить.
- `demo_isolation_test.dart`, `demo_flow_test.dart` - переопределения `appConfigProvider/apiClientProvider`; новые провайдеры (`orgContextProvider`, репозитории) должны тоже подчиняться флагу, иначе в тестах уйдёт реальный HTTP.
- `login_screen_test.dart`, `verify_email_test.dart` - `signIn` теперь триггерит загрузку контекста; в тестах без override это даст запрос `/organizations/me`.
- `analysis_screen_test.dart`, `material_catalog_test.dart`, `material_screens_test.dart`, `test/support/material_fakes.dart` - используют сессию/роль; фейки нужно дополнить `orgContext` override (хелпер `pumpAsRole(role)` в `test/support`).
Вывод: сначала добавить тестовый хелпер с override контекста, потом менять код; контекст должен иметь безопасный default для тестов без override.

Демо-изоляция: новые репозитории и контекст легко забыть подключить к флагу; admin/модерация в демо; общее демо-хранилище между ролями. Митигация: единый паттерн провайдера, тест «ни один Api* репозиторий не создаётся в demo» через перебор провайдеров, запрет admin в демо.

Рост сложности: вторая ось (организация) поверх роли, права, 7 репозиториев, 3 дашборда. Митигация: этапность (контекст -> маршруты -> нужные репозитории), не вводить `ShellRoute`/code-gen/новые зависимости, не строить UI под эндпоинты без контракта (приглашения, членство, модерация - только после решения оркестратора). Отдельно: `UserRole.parse` с молчаливым `buyer` по умолчанию опасен (неизвестная роль станет покупателем) - заменить на явное `unknown` с экраном ошибки.

## 8. Оценка (грубо, дни одного разработчика)

| # | Задача | Дни |
|---|---|---|
| 1 | Тестовый хелпер ролей/контекста, безопасный default, `UserRole.unknown` | 0.5 |
| 2 | `OrgContext` модель, репозиторий (API + демо), провайдер, сброс user-scoped состояния | 1.5 |
| 3 | Расширенный `authRedirect`, `routeRoles`, `/no-organization`, тесты guard | 1 |
| 4 | Permission API (`Can`, ошибки 403/404/409 в `ApiException`, `ErrorPanel`) + тесты | 1 |
| 5 | `navItemsFor(role)`, диспетчер `HomeScreen`, `BuyerDashboard` | 1.5 |
| 6 | Reservations (список, действия, 409, идемпотентность) | 2.5 |
| 7 | Buyer requirements (список, форма) | 1.5 |
| 8 | Демо-сиды buyer/recycler + изоляция + тесты | 1 |
| 9 | Членство / приглашения / модерация (интерфейс + демо; Api - после контракта) | 2-3 |
| 10 | Прогон существующих тестов, правка, форматирование, analyze | 1 |

Итого около 13-15 дней; без п. 9 - около 11. Порядок: 1 -> 2 -> 3 -> 4 -> 5 -> 8 -> 6 -> 7 -> 10 -> 9. Пункты 6, 7 зависят только от уже описанного в api.md; пункт 9 блокирован контрактом.

## Допущения и вопросы к оркестратору

- Модель «много членств на пользователя» противоречит упрощению MVP (одна организация); план закладывает интерфейс, но UI смены организации не строится, пока backend не даст контракт.
- Нужны от backend: поле `permissions`/`role_in_org` (если решено), коды ошибок при смене роли, эндпоинты membership/invitations/moderation, политика отзыва токена при смене роли.
- Хранение токена в памяти сохраняется; персистентная сессия - отдельное решение.
