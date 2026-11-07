# ARTA: модель ролей и прав (RBAC), план

Статус: **проект, не реализован**. Дата: 2026-11-07. Код, миграции и `docs/api.md` этим документом не менялись.
Связанные документы: `organization-membership.md` (таблицы), `multi-role-api-plan.md` (эндпоинты).
Пометка «Решение N» отсылает к списку «Решения, требующие владельца» в конце этого файла.

## 1. Что есть сейчас (факт из кода на 2026-11-07)

| Область | Статус | Факт |
| --- | --- | --- |
| Роль аккаунта | реализовано | `users.role` (`enterprise` / `buyer` / `admin`, `backend/app/models/enums.py`), одна на пользователя |
| Организация пользователя | реализовано | `users.organization_id` NOT NULL, один пользователь = одна организация; регистрация всегда создаёт новую организацию (`services/auth.py`) |
| Проверка роли | реализовано | `require_roles(...)` в `api/deps.py`; `EnterpriseUser`, `CatalogUser`, `BuyerUser`, `AdminUser` |
| Владение ресурсом | реализовано | сравнение `organization_id` ресурса с `user.organization_id` (`get_owned`, `owned_reservation`, `OptimizationRun`, `BuyerRequirement`); чужой объект = 404 |
| Тип организации | частично | `organizations.activity_type` (`garment_factory`, `workshop`, `recycler`, `other`). Переработчик = `buyer` + `activity_type=recycler`; ограничение проверяется по `user.role`, а не по организации |
| Членство (membership) | отсутствует | нет таблиц, нет ролей OWNER/MANAGER/MEMBER, нет приглашений |
| Права (permissions) | отсутствует | нет идентификаторов прав, проверяются только роли |
| Несколько организаций / переключение | отсутствует | JWT содержит только `sub`, `iat`, `exp` (`core/security.py`) |
| Аудит | частично | только строка лога `arta.admin.audit` при блокировке пользователя админом (`api/admin.py`); таблицы нет; в `materials`/`reservations` нет поля «кем создано» |
| Admin | реализовано | роль создаётся только `python -m app.create_admin`; `/admin/api/*` под `require_roles(Role.admin)`; в бизнес-маршрутах admin получает 403; организация admin («Администрация ARTA») формальная |
| Подтверждение email | реализовано | `users.email_confirmed`, вход без подтверждения = 403 `EMAIL_NOT_CONFIRMED` |
| Idempotency | реализовано | `idempotency_records`, `UNIQUE(user_id, operation, key)` |

Только документация (в `api.md`, кода нет): `GET /materials/{id}/images/{image_id}/url` (8.5, A20-8). Заблокировано: реальная отправка почты и Supabase Storage не проверялись (см. `api.md` 23.8, 20).

## 2. Принципы

1. **Глобальной роли аккаунта недостаточно.** Для действия над данными организации нужны одновременно: (a) активная учётная запись с подтверждённым email; (b) **активное членство** пользователя в активной организации запроса; (c) **право** (permission), которое даёт роль членства в сочетании со стороной организации; (d) **владение ресурсом**, проверяемое отдельно.
2. **Тип организации и право пользователя разные вещи.** Тип организации (сторона `supplier` / `buyer` / `platform` + `activity_type`) определяет, какие *группы* прав организация вообще может иметь. Роль членства определяет, какие из них получает *конкретный пользователь*. Пересечение, а не объединение: MANAGER покупателя не получает `materials:publish`, потому что организация-покупатель не поставщик.
3. **Владение ресурсом отдельно от права.** Право `materials:write` не открывает чужую партию: после проверки права ресурс ищется по `organization_id = активная организация`; иначе 404. Для заявок владение двустороннее (`seller_organization_id` / `buyer_organization_id`).
4. **Порядок проверок (сохраняет контракт `api.md` 19.1):** 401 (токен/пользователь) -> 429 -> **403 по праву** (до обращения к ресурсу, ответ не зависит от существования объекта) -> 404 (нет объекта в активной организации либо чужой скрытый) -> 422 -> блокировка строки -> 409.
5. Права не кэшируются в JWT: вычисляются на каждом запросе из БД (см. `organization-membership.md`, раздел «Изменение роли во время сессии»).
6. Фронтенд не источник истины: скрытие кнопок не заменяет проверку API.

## 3. Платформенные роли

| Роль | Источник | Смысл | Членство нужно |
| --- | --- | --- | --- |
| `enterprise` | `users.role` / сторона организации `supplier` | поставщик остатков: партии, анализы, планы, продажа | да |
| `buyer` | `users.role` / сторона `buyer` | покупатель: потребности, заявки | да |
| `recycler` | не отдельная роль: `buyer` + `activity_type=recycler` (как в `CLAUDE.md` §4) | покупатель-переработчик | да |
| `admin` | `users.role=admin`, создаётся только консолью | модерация и поддержка платформы | **нет** (платформенный контур, раздел 7) |

Предложение: в переходный период `users.role` остаётся и дублирует сторону организации (для `enterprise`/`buyer`) либо платформенную роль `admin`. После внедрения источник истины для бизнес-прав: `organizations.side` + `organization_memberships.role`. Решение 1.

## 4. Типы организаций

| Поле | Значения | Статус | Назначение |
| --- | --- | --- | --- |
| `organizations.activity_type` | `garment_factory`, `workshop`, `recycler`, `other` | реализовано | описание деятельности, влияет на matching (переработчик) |
| `organizations.side` (новое) | `supplier`, `buyer`, `platform` | предложение | определяет допустимые группы прав; значение выводится из роли при регистрации (`enterprise` -> `supplier`, `buyer` -> `buyer`, организация admin -> `platform`) |

Одна организация = одна сторона в MVP. Организация, одновременно продающая и покупающая, не поддерживается (Решение 2). Ограничение «recycler только у buyer» переносится с `user.role` на `organizations.side`.

## 5. Роли членства

| Роль | Смысл |
| --- | --- |
| `OWNER` | полный набор прав стороны организации + управление участниками, профилем и аудитом. Минимум один активный OWNER на организацию |
| `MANAGER` | операционные действия стороны (включая необратимые: публикация, подтверждение резерва, передача); участников только читает и приглашает MEMBER (Решение 3) |
| `MEMBER` | подготовка данных и чтение: черновики, фото, анализ, заявка/потребность на чтение; необратимых и внешне видимых действий нет |

## 6. Идентификаторы прав

Формат `ресурс:действие`, нижний регистр, фиксированный реестр в коде (одна константа, не строки по роутам). Колонка «Сторона» ограничивает, какие организации вообще могут иметь право.

| Право | Сторона | Что разрешает | Маршруты (сейчас/план) |
| --- | --- | --- | --- |
| `organizations:read` | все | свой профиль | GET `/organizations/me` |
| `organizations:write` | все | менять название/город/контакты | PATCH `/organizations/me` |
| `members:read` | все | список участников и своё членство | GET `/organizations/me/members` |
| `members:invite` | все | создавать/отзывать приглашения | POST/GET/DELETE `/organizations/me/invitations` |
| `members:manage` | все | менять роль, блокировать, удалять участника | PATCH/DELETE `/organizations/me/members/{id}` |
| `audit:read` | все | читать журнал своей организации | GET `/audit-log` |
| `materials:read` | supplier | свои партии любого статуса | GET `/materials`, `/materials/{id}` |
| `materials:write` | supplier | создать/изменить черновик, фото | POST/PATCH `/materials`, `/images` |
| `materials:confirm` | supplier | человеческое подтверждение характеристик | POST `/materials/{id}/confirm` |
| `materials:publish` | supplier | публикация | POST `/materials/{id}/publish` |
| `materials:archive` | supplier | архивация | POST `/materials/{id}/archive` |
| `materials:internal_use` | supplier | внутреннее использование (меняет остаток) | POST `/materials/{id}/internal-use` |
| `catalog:browse` | buyer | опубликованные партии (`MaterialPublicOut`) | GET `/materials*` для buyer |
| `ai:analyze` | supplier | запуск анализа, чтение анализа | POST `/ai/analyze`, GET `/ai/analyses/{id}` |
| `ai:match` | supplier | matching | POST `/ai/match` |
| `optimization:run` | supplier | расчёт плана | POST `/optimization/run` |
| `optimization:read` | supplier | чтение плана | GET `/optimization/runs/{id}` |
| `requirements:read` | buyer, supplier | buyer: свои; supplier: публичные активные (без бюджета и контактов) | GET `/buyer-requirements` |
| `requirements:write` | buyer | создание/изменение потребности | POST/PATCH `/buyer-requirements` |
| `reservations:create` | buyer | заявка | POST `/reservations` |
| `reservations:read` | supplier, buyer | заявки своей стороны | GET `/reservations` |
| `reservations:confirm` | supplier | подтвердить резерв (удержание массы) | PATCH action=confirm |
| `reservations:transfer` | supplier | зафиксировать передачу | PATCH action=transfer |
| `reservations:cancel` | supplier, buyer | отмена/отказ (продавец с причиной) | PATCH action=cancel |
| `reservations:complete` | buyer | подтвердить получение | PATCH action=complete |
| `reuse:confirm` | buyer | подтверждение использования | POST `/transactions/{id}/reuse-confirmation` |
| `analytics:read` | supplier, buyer | своя аналитика | GET `/analytics/summary` |
| `admin:read` | platform | читать записи админ-панели | GET `/admin/api/*` |
| `admin:users_access` | platform | блокировать/разблокировать не-admin пользователей | PATCH `/admin/api/users/{id}/access` |

## 7. Матрица «право -> роль членства -> условие»

Обозначения: В = выдаётся по умолчанию; — = не выдаётся. «Владение» = ресурс принадлежит активной организации (проверяется отдельно, всегда). «Членство» = активное членство в активной организации (проверяется всегда).

### 7.1 Организация и участники

| Право | OWNER | MANAGER | MEMBER | Условие |
| --- | --- | --- | --- | --- |
| `organizations:read` | В | В | В | членство |
| `organizations:write` | В | — | — | членство; для `activity_type=recycler` дополнительно `side=buyer` |
| `members:read` | В | В | В | членство |
| `members:invite` | В | В (только роль MEMBER) | — | членство; приглашаемая роль не выше своей, OWNER выдаётся только передачей владения |
| `members:manage` | В | — | — | членство; нельзя понизить/удалить последнего OWNER; нельзя изменить себя в ходе того же запроса, кроме `leave` |
| `audit:read` | В | — | — | членство, только журнал активной организации |

### 7.2 Сторона supplier (`enterprise`)

| Право | OWNER | MANAGER | MEMBER | Условие владения |
| --- | --- | --- | --- | --- |
| `materials:read` | В | В | В | `material.organization_id` = активная |
| `materials:write` | В | В | В | то же; ограничения `ACTIVE_OBLIGATIONS` сохраняются |
| `materials:confirm` | В | В | — | то же (Решение 4) |
| `materials:publish` | В | В | — | то же |
| `materials:archive` | В | В | — | то же |
| `materials:internal_use` | В | В | — | то же |
| `ai:analyze` | В | В | В | материал своей организации |
| `ai:match` / `optimization:run` / `optimization:read` | В | В | `optimization:read` и `ai:match` В; `optimization:run` — | материалы/план своей организации |
| `reservations:read` | В | В | В | `seller_organization_id` = активная |
| `reservations:confirm` / `transfer` / `cancel` | В | В | — | `seller_organization_id` = активная |
| `requirements:read` | В | В | В | публичный вид без бюджета и контактов |
| `analytics:read` | В | В | В | аналитика активной организации |

### 7.3 Сторона buyer (`buyer`, `recycler`)

| Право | OWNER | MANAGER | MEMBER | Условие владения |
| --- | --- | --- | --- | --- |
| `catalog:browse` | В | В | В | партия в статусах `available`/`partially_allocated`, `available_kg > 0`; иначе 404 |
| `requirements:read` | В | В | В | `requirement.organization_id` = активная |
| `requirements:write` | В | В | — | то же |
| `reservations:create` | В | В | — | партия видима buyer; `requirement_id` (если есть) своей организации |
| `reservations:read` | В | В | В | `buyer_organization_id` = активная |
| `reservations:cancel` | В | В | — | `buyer_organization_id` = активная |
| `reservations:complete` | В | В | — | то же |
| `reuse:confirm` | В | В | — | сделка по заявке своей организации |
| `analytics:read` | В | В | В | сокращённая аналитика покупателя |

### 7.4 Платформенный контур

| Право | admin | Условие |
| --- | --- | --- |
| `admin:read` | В | `users.role=admin`, активный, подтверждён; **членство не требуется**; бизнес-права организаций admin не получает (403 в бизнес-маршрутах, как сейчас) |
| `admin:users_access` | В | цель не admin (409 `ADMIN_ACCOUNT_PROTECTED` как сейчас); действие пишется в `audit_log` |

Admin не может быть приглашён в организации и не может переключаться на чужие организации (Решение 5).

## 8. Правило вычисления

```
effective_permissions(user, org_id) =
    ∅                                   если user.active=false или email не подтверждён
    ADMIN_PERMS                         если user.role=admin и маршрут /admin/api/*
    ∅                                   если нет активного membership(user, org_id)
    ROLE_GRANTS[membership.role] ∩ SIDE_ALLOWED[org.side]   иначе
```

`ROLE_GRANTS` и `SIDE_ALLOWED` — две статические таблицы в одном модуле (`app/core/permissions.py`, имя предложение), без хранения прав в БД на первом этапе (кастомные роли не нужны для MVP). Изменение таблиц — через код и тесты матрицы.

## 9. Тесты матрицы (план, не написаны)

- параметризованный тест «право × роль членства × сторона» на фиксированной таблице раздела 7;
- buyer, вызывающий publish/archive, получает 403 для существующей, чужой и несуществующей партии (одинаково);
- MEMBER supplier получает 403 на publish до обращения к ресурсу;
- пользователь с двумя организациями: действие в организации A не видит данные B (404);
- понижение роли и блокировка применяются со следующего запроса с тем же токеном.

## Решения, требующие владельца

1. Статус `users.role`: оставить как платформенную роль (admin) + зеркало стороны на переходный период, затем удалить; или оставить навсегда. По умолчанию плана: зеркало, источник истины — сторона организации и членство.
2. Может ли одна организация быть и поставщиком, и покупателем (`side=both`)? План исходит из «нет» (как `api.md` 1.1).
3. Может ли MANAGER приглашать и снимать MEMBER, или управление участниками только у OWNER? План: приглашать MEMBER может, снимать нет.
4. Должен ли MEMBER поставщика подтверждать характеристики (`materials:confirm`) и запускать расчёт плана? План: нет (подтверждение = юридически значимое действие человека, `CLAUDE.md` §6).
5. Нужен ли admin доступ «действовать от имени» организации (impersonation)? План: нет, только чтение через панель.
