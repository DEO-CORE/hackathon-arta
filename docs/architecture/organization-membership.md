# ARTA: членство в организациях, приглашения, аудит (проект схемы)

Статус: **проект, не реализован, миграции не созданы**. Дата: 2026-11-07.
Права и матрица: `rbac-permissions.md`. Эндпоинты: `multi-role-api-plan.md`.
Допущения помечены A-M-n. Решения владельца — в конце `multi-role-api-plan.md`.

## 1. Текущее состояние (факт)

- `users.organization_id` NOT NULL FK -> `organizations.id`; одна организация на пользователя, организация создаётся при регистрации; присоединиться по ID нельзя (`services/auth.py`).
- JWT: `sub`, `iat`, `exp`, алгоритм HS256 из allowlist; ни организации, ни роли в токене нет. Пользователь и `active` читаются из БД на каждом запросе (`api/deps.py`).
- Таблиц `organization_memberships`, `organization_invitations`, `audit_log` нет. Единственный аудит: строка лога при блокировке пользователя админом.
- Есть готовые механизмы для повторного использования: HMAC-хеш одноразового кода (`email_codes`, `EMAIL_CODE_HMAC_KEY`), почтовый адаптер (`integrations/mail`, реальная отправка не проверялась), процессный `RateLimiter`, `idempotency_records`.
- Ограничения БД проекта: UUID PK, `timestamptz`, enum как `VARCHAR + CHECK` (`native_enum=False, create_constraint=True`), как в существующих моделях.

## 2. Таблица `organization_memberships`

**Назначение:** связь «пользователь состоит в организации с ролью». Единственный источник истины для прав в организации.

| Поле | Тип | Ограничения |
| --- | --- | --- |
| `id` | UUID | PK |
| `user_id` | UUID | NOT NULL, FK `users.id` ON DELETE RESTRICT |
| `organization_id` | UUID | NOT NULL, FK `organizations.id` ON DELETE RESTRICT |
| `role` | VARCHAR(16) | NOT NULL, CHECK IN (`OWNER`,`MANAGER`,`MEMBER`) |
| `status` | VARCHAR(16) | NOT NULL, CHECK IN (`active`,`suspended`,`removed`), по умолчанию `active` |
| `invited_by_user_id` | UUID | NULL, FK `users.id`; NULL для первого OWNER и backfill |
| `version` | INTEGER | NOT NULL, по умолчанию 1; оптимистичная блокировка |
| `created_at`, `updated_at` | timestamptz | NOT NULL, UTC |
| `removed_at` | timestamptz | NULL; CHECK (`status`='removed') = (`removed_at` IS NOT NULL) |

Ограничения и индексы:

- `UNIQUE (user_id, organization_id)` — одна запись на пару; повторное вступление после `removed` **реактивирует** строку (`status='active'`, новая роль, `version+1`, `removed_at=NULL`), а не создаёт вторую. История — в `audit_log`.
- индекс `(organization_id, status, role)` — список участников, подсчёт активных OWNER;
- индекс `(user_id, status)` — список организаций пользователя, переключение;
- защита «последнего OWNER»: не через unique-индекс, а в сервисе под `SELECT ... FOR UPDATE` строки `organizations` (порядок блокировок раздел 9); дополнительно конструктивный тест на конкурентное понижение двух OWNER.

**Границы владения:** запись принадлежит организации; читает её любой активный участник той же организации (`members:read`); изменяет только `members:manage`. Пользователь видит *свои* членства во всех организациях через `GET /auth/me`, но не членства других. Админ читает через панель (`admin:read`), не изменяет.

**Дополнительно на `users` (предложение):** `default_organization_id UUID NULL FK organizations.id` — какую организацию выбирать, если токен выдан без явного выбора. `users.organization_id` остаётся на переходный период (раздел 8), помечен deprecated.

## 3. Таблица `organization_invitations`

**Назначение:** одноразовое приглашение конкретного email в организацию с конкретной ролью.

| Поле | Тип | Ограничения |
| --- | --- | --- |
| `id` | UUID | PK |
| `organization_id` | UUID | NOT NULL, FK `organizations.id` ON DELETE CASCADE |
| `email` | VARCHAR(254) | NOT NULL, нижний регистр (как `users.email`) |
| `role` | VARCHAR(16) | NOT NULL, CHECK IN (`MANAGER`,`MEMBER`); **`OWNER` приглашением выдать нельзя** |
| `token_hash` | CHAR(64) | NOT NULL, UNIQUE; HMAC-SHA256 токена, сам токен не хранится |
| `status` | VARCHAR(16) | NOT NULL, CHECK IN (`pending`,`accepted`,`revoked`,`expired`) |
| `expires_at` | timestamptz | NOT NULL; CHECK `expires_at > created_at` |
| `created_by_user_id` | UUID | NOT NULL, FK `users.id` |
| `created_at` | timestamptz | NOT NULL |
| `accepted_at` | timestamptz | NULL |
| `accepted_by_user_id` | UUID | NULL, FK `users.id`; CHECK: `status='accepted'` тогда и только тогда `accepted_at` и `accepted_by_user_id` NOT NULL |
| `revoked_at`, `revoked_by_user_id` | timestamptz / UUID | NULL |
| `failed_attempts` | INTEGER | NOT NULL, 0; счётчик неудачных принятий именно этого приглашения (для блокировки, A-M-3) |

Индексы и уникальность:

- `UNIQUE (token_hash)`;
- частичный `UNIQUE (organization_id, email) WHERE status='pending'` — не более одного живого приглашения на email в организации; повторное приглашение = отзыв прежнего + новое в одной транзакции;
- индекс `(organization_id, status, created_at DESC)`;
- индекс `(email) WHERE status='pending'` — для `GET /invitations/mine`, если он понадобится (не в первом этапе).

Токен: 32 случайных байта (`secrets.token_urlsafe(32)`), показывается только в письме (в ответе API его нет; в demo-режиме по аналогии с кодом `7777` допускается фиксированный путь, A-M-4). Хеш — HMAC-SHA256 с отдельным ключом (`INVITATION_HMAC_KEY`, >= 32 символов, без значения по умолчанию; не повторять `EMAIL_CODE_HMAC_KEY`). Токен, письмо и email не пишутся в логи и `audit_log.details`.

**Одноразовость:** принятие выполняется одним условным `UPDATE ... SET status='accepted', accepted_* WHERE token_hash=:h AND status='pending' AND expires_at>now() RETURNING *`; 0 строк = приглашение недействительно (одинаковый ответ для неизвестного, просроченного, использованного, отозванного). Создание членства в той же транзакции.

Срок жизни: 72 часа (A-M-1, допущение). Просрочка вычисляется по `expires_at` на чтении; статус `expired` проставляется лениво или фоновой чисткой при необходимости (отдельный сервис не создаётся).

**Границы владения:** принадлежит организации-приглашающей. Создаёт/отзывает/читает список `members:invite` (без `token_hash`). Принимает любой аутентифицированный пользователь, чей подтверждённый email равен `invitations.email`; членство организации этому не требуется. Приглашённый не видит данных организации до принятия.

## 4. Таблица `audit_log`

**Назначение:** append-only журнал «кто, что, когда, над чем» для действий, меняющих права, членство, остатки и состояние сделок. Не заменяет бизнес-данные (`impact_records`, `transactions`) и не содержит секретов.

| Поле | Тип | Ограничения |
| --- | --- | --- |
| `id` | BIGINT identity | PK (монотонный порядок) |
| `occurred_at` | timestamptz | NOT NULL, серверное UTC |
| `actor_user_id` | UUID | NULL, FK `users.id` ON DELETE RESTRICT (NULL = система/консоль) |
| `actor_membership_role` | VARCHAR(16) | NULL; снимок роли на момент действия |
| `actor_platform_role` | VARCHAR(16) | NULL; `admin` для действий панели |
| `organization_id` | UUID | NULL, FK `organizations.id`; NULL для платформенных действий |
| `action` | VARCHAR(64) | NOT NULL, из реестра (пример: `membership.role_changed`, `invitation.created`, `invitation.accepted`, `material.published`, `reservation.confirmed`, `org.switched`, `user.access_changed`, `permission.denied`) |
| `resource_type` | VARCHAR(32) | NOT NULL |
| `resource_id` | UUID | NULL |
| `outcome` | VARCHAR(16) | NOT NULL, CHECK IN (`success`,`denied`,`conflict`) |
| `request_id` | VARCHAR(64) | NULL; тот же `X-Request-ID` |
| `details` | JSONB | NOT NULL, по умолчанию `{}`; **белый список ключей** (`from_role`, `to_role`, `version`, `reason_code`), без email, телефонов, токенов, подписанных URL, текста пользователя |

Индексы: `(organization_id, occurred_at DESC)`, `(actor_user_id, occurred_at DESC)`, `(resource_type, resource_id, occurred_at DESC)`.

Неизменяемость: приложение имеет только INSERT; в миграции — триггер, запрещающий UPDATE/DELETE (рекомендация; проверяется интеграционным тестом). Срок хранения — вне MVP (A-M-5: хранить без очистки).

Запись производится **в той же транзакции**, что и действие (успех), а для `denied` — отдельной короткой транзакцией после отказа, чтобы rollback бизнес-операции не стирал след. Ограничение объёма: `denied` пишется только для действий управления членством и приглашений (не для каждого 403, иначе журнал станет вектором DoS).

**Границы владения:** запись принадлежит организации (`organization_id`); читает `audit:read` (OWNER) только записи своей организации; записи с `organization_id IS NULL` — только admin-панель. Другой организации записи не видны; прямой выдачи по id нет.

Отдельно не входит в этот этап: поле `created_by_user_id` / `updated_by_user_id` в `materials`, `reservations`, `transactions` (сейчас хранится только организация). Без него «кто именно из сотрудников» восстанавливается только по `audit_log`. Решение о добавлении — отдельная миграция позже.

## 5. Несколько организаций на пользователя

- Пользователь может иметь несколько записей `organization_memberships` (Решение 8). Одна **активная организация** на запрос.
- Активная организация определяется claim `org` в access token (раздел 6). Токен без `org` (старые токены, обычный логин) трактуется как `users.default_organization_id`; если он NULL и членств ровно одно — это оно; иначе 409 `ORGANIZATION_SELECTION_REQUIRED` (маршруты `/auth/me`, `/auth/switch-organization` при этом доступны).
- Сторона (`supplier`/`buyer`) у разных организаций пользователя может отличаться, поэтому доступные маршруты зависят от активной организации, а не от аккаунта. Клиент обязан перезагрузить каталог/состояние после переключения.
- Идемпотентность и rate limit: `idempotency_records` остаётся в области `(user_id, operation, key)`; `operation` дополняется id активной организации, чтобы ключ не пересекался между организациями (A-M-6).

## 6. Переключение организации

- `POST /auth/switch-organization {organization_id}` проверяет активное членство и выдаёт **новый** access token с `org=<id>`; старый токен остаётся валидным до `exp` (stateless JWT; отзыва списком не вводим, A-M-7), поэтому все проверки членства на каждом запросе обязательны.
- Токен содержит только `sub`, `org`, `iat`, `exp`. Роль и права **не** кладутся в токен.
- Несуществующая организация и организация без активного членства — один и тот же ответ 404 (существование не раскрывается).
- Событие `org.switched` пишется в `audit_log`.
- Лимит: тот же класс rate limit, что у логина по пользователю.

## 7. Приглашения и защита от злоупотреблений

| Угроза | Мера |
| --- | --- |
| Перебор токена | 256 бит энтропии, сравнение по HMAC-хешу; лимит `POST /invitations/accept` на пользователя и IP; счётчик `failed_attempts` на приглашении после опознания записи (A-M-3: 5 неудач блокируют приглашение, статус `revoked`) |
| Принятие чужого приглашения | email пользователя (подтверждённый) должен совпадать с `invitations.email`; иначе тот же ответ, что для неизвестного токена |
| Перечисление аккаунтов | ответ создания приглашения одинаков для существующего и несуществующего email; приглашение живёт независимо от наличия аккаунта |
| Эскалация прав | в приглашении нельзя указать роль выше роли пригласившего и нельзя `OWNER`; роль берётся с сервера, а не из токена |
| Спам email | лимит приглашений на организацию (50 pending, 20 в сутки — A-M-8) и на пользователя; один pending на email |
| Утечка токена | токен только в письме, хеш в БД, не логируется; одноразовость; короткий срок; отзыв |
| Повторное принятие / гонка | условный UPDATE (раздел 3); `UNIQUE (user_id, organization_id)` останавливает дубль членства |
| Принятие пользователем admin | запрещено: 409 `PRECONDITION_FAILED`, `reason=ADMIN_CANNOT_JOIN` |
| Вступление в организацию противоположной стороны | допустимо (A-M-9): сторона у организации, не у пользователя |
| Доставка | без настроенной почты создание приглашения = 503 `EMAIL_DELIVERY_UNAVAILABLE` (по образцу `api.md` 23.8), токен в ответе не возвращается |

## 8. Изменение роли во время активной сессии

- Права вычисляются из БД на каждом запросе (читается строка членства по `(user_id, org)`); JWT не кэширует роль. Понижение роли, `suspended`, `removed` действуют **со следующего запроса** с тем же токеном; длительность окна = время выполнения одного запроса.
- Запрос, уже начавший транзакцию, не перепроверяет членство повторно (A-M-10); для необратимых операций (confirm/transfer резерва, internal-use, publish) проверка выполняется до блокировок ресурсов, внешние вызовы блокировок не удерживают.
- Активная организация, в которой членство перестало быть активным: все бизнес-маршруты отвечают 403 `MEMBERSHIP_INACTIVE` (пользователь знает о своей организации, раскрытия нет); `/auth/me` и `/auth/switch-organization` работают, чтобы клиент мог выбрать другую.
- Понижение/удаление пользователя при его активных обязательствах: данные остаются за организацией (сделки, партии не «уходят» с участником). Незавершённые асинхронные AI-задачи и планы принадлежат организации, а не участнику.
- Блокировка аккаунта админом (`users.active=false`) по-прежнему даёт 401 на следующий запрос во всех организациях.
- Смена роли идёт по `version` членства: `PATCH` с устаревшей `version` = 409 `VERSION_CONFLICT`.

## 9. Порядок блокировок

Единый порядок, дополняющий D-08 (`materials` -> `buyer_requirements` -> `reservations` -> `transactions`): `organizations` -> `organization_memberships` (по `id`) выполняется **только в операциях управления участниками** и не совмещается с блокировками остатков в одной транзакции. Операции управления участниками материалы и заявки не блокируют.

## 10. Миграция существующих данных (кратко; подробные риски в `multi-role-api-plan.md`)

Backfill: для каждого `users` с `role IN ('enterprise','buyer')` создать членство `OWNER`/`active` в `users.organization_id`; `default_organization_id = organization_id`; `organizations.side` вывести из `users.role` организации. Admin: членство не создаётся. Миграция выполняется одним агентом, отдельно от прочих (правило проекта).

## Допущения

- A-M-1: срок приглашения 72 ч. A-M-2: роль `OWNER` приглашением не выдаётся. A-M-3: 5 неудач блокируют приглашение. A-M-4: в demo режиме токен приглашения не отправляется почтой, а выдаётся фиксированным демо-путём (только `DEMO_MODE`). A-M-5: аудит без срока хранения. A-M-6: `operation` идемпотентности включает id организации. A-M-7: нет отзыва уже выданных JWT, кроме блокировки пользователя и проверки членства на каждом запросе. A-M-8: лимиты 50 pending / 20 в сутки на организацию. A-M-9: приглашаться можно независимо от стороны пользователя. A-M-10: членство проверяется один раз на запрос.
