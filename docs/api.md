# ARTA REST API, контракт v1

Статус: черновик CON-01, ожидает утверждения оркестратором. Владелец файла: backend-engineer.
Источники: `CLAUDE.md` §4, §5, §9, §10, §11; `docs/decisions.md` D-05, D-06, D-08.
Любое изменение маршрута, кода ошибки или DTO вносится в этот файл в том же изменении, что и код.

Метка «допущение» означает решение, которого нет в `CLAUDE.md`; все допущения собраны в разделе 16.
Метка «дополнительный» означает маршрут сверх `CLAUDE.md` §9, без которого нельзя пройти сценарий §2.
Метка «предварительно» означает DTO, окончательная форма которого определяется CON-02 (AI) или CON-03 (matching/optimizer); при расхождении приоритет у этих контрактов, после чего этот файл обновляется.

## 1. Общие правила

- Формат: JSON, `Content-Type: application/json` (кроме загрузки фото, см. 8.4). Кодировка UTF-8.
- Авторизация: заголовок `Authorization: Bearer <access_token>` на всех маршрутах, кроме `POST /auth/register`, `POST /auth/login`, `GET /health`.
- Идентификаторы: UUID (строка в каноническом виде).
- Время: UTC, ISO 8601 с суффиксом `Z`, например `2026-11-06T10:15:30Z`. Поля называются `*_at`.
- Масса (`*_kg`): строка decimal, не более 3 знаков после точки, значение >= 0, до 9 цифр целой части. Пример: `"125.500"`.
- Деньги (`*_kgs`, `*_per_kg`): строка decimal, не более 2 знаков после точки, значение >= 0, до 12 цифр целой части. Валюта всегда KGS. Пример: `"48.00"`.
- Число JSON (`125.5`) вместо строки для массы и денег отклоняется с 422. Лишние знаки после точки отклоняются с 422, а не округляются. В ответах масса всегда с 3 знаками, деньги с 2.
- Баллы и проценты, не являющиеся массой и деньгами: `score` — целое 0..100; `allocation_efficiency_pct` — строка decimal с 2 знаками.
- Поле, значение которого неизвестно, возвращается как `null`, а не как выдуманное значение.
- `request_id`: сервер присваивает каждому запросу и возвращает в заголовке `X-Request-ID` и в теле ошибки.
- Лишние поля в теле запроса отклоняются с 422 (`extra = forbid`).
- Клиент не передаёт `id`, `organization_id`, `created_at`, остатки, статус партии и `version`, выданную сервером, как значения для записи (исключение: `version` в PATCH/confirm как условие, см. раздел 4).
- OpenAPI (`/openapi.json`) генерируется FastAPI и должен совпадать с этим файлом; расхождение — дефект.

### 1.1 Роли

| Роль | Как получить |
| --- | --- |
| `enterprise` | `POST /auth/register`, `role = "enterprise"` |
| `buyer` | `POST /auth/register`, `role = "buyer"`; переработчик — `buyer` с `organization.activity_type = "recycler"` |
| `admin` | Не назначается через API. Модерационных маршрутов в v1 нет |

Один пользователь принадлежит одной организации (упрощение MVP).
Проверка роли, организации и владения выполняется на каждом запросе, включая вложенные ID (`image_id`, `analysis_id`, `requirement_id`, `transaction_id`). Для чужих скрытых объектов возвращается 404, для известного, но запрещённого действия по роли — 403.

### 1.2 Единый формат ошибки

Все ошибки (включая 401, 404, 422, 429, 5xx) возвращаются в одном формате. Traceback, SQL и внутренние сообщения не возвращаются.

```json
{
  "error": {
    "code": "INSUFFICIENT_STOCK",
    "message": "Недостаточно свободной массы для резерва.",
    "details": { "available_kg": "10.000", "requested_kg": "25.000" },
    "request_id": "9f0c2c9e-6d2b-4b5a-8f3e-2f1d5e7a1c11"
  }
}
```

| Поле | Тип | Описание |
| --- | --- | --- |
| `error.code` | string | Стабильный машинный код из таблицы ниже |
| `error.message` | string | Безопасное сообщение на русском, без внутренних данных |
| `error.details` | object или null | Необязательно. Для 422: `{"errors": [{"field": "min_kg", "code": "...", "message": "..."}]}` |
| `error.request_id` | string | Совпадает с `X-Request-ID` |

Коды ошибок:

| HTTP | `code` | Когда |
| --- | --- | --- |
| 401 | `UNAUTHENTICATED` | Нет токена, неверная подпись, истёк `exp`, неверный алгоритм, пользователь неактивен |
| 401 | `INVALID_CREDENTIALS` | Неверный email или пароль при входе (одно сообщение на оба случая) |
| 403 | `FORBIDDEN` | Роль не допускает действие |
| 403 | `ACCOUNT_DISABLED` | Верный пароль, но учётная запись отключена (18.9) |
| 404 | `NOT_FOUND` | Объекта нет или он скрыт от этого пользователя |
| 409 | `VERSION_CONFLICT` | Передана устаревшая `version` |
| 409 | `INSUFFICIENT_STOCK` | Свободной массы партии меньше запрошенной (проверка внутри транзакции) |
| 409 | `DEMAND_EXCEEDED` | Оставшегося спроса потребности меньше запрошенной массы |
| 409 | `INVALID_TRANSITION` | Действие недопустимо в текущем статусе заявки или партии |
| 409 | `ACTIVE_OBLIGATIONS` | Изменение запрещено из-за активных резервов или переданной массы |
| 409 | `IMAGE_LIMIT_REACHED` | Уже 5 фото на партии |
| 409 | `PRECONDITION_FAILED` | Не выполнено условие состояния (например, анализ без фото, подтверждение без актуального анализа) |
| 409 | `IDEMPOTENCY_KEY_REUSED` | Тот же `Idempotency-Key` с другим payload |
| 409 | `EMAIL_ALREADY_REGISTERED` | Email уже занят (допущение, см. 16) |
| 422 | `VALIDATION_ERROR` | Неверные типы, диапазоны, форматы, лишние поля, нарушение инвариантов (`min_kg <= max_kg`, масса > 0) |
| 422 | `PUBLISH_REQUIREMENTS_NOT_MET` | Публикация без обязательных данных; `details.missing` — список полей/условий |
| 422 | `UNSUPPORTED_IMAGE` | Формат не JPEG/PNG/WebP, не совпала сигнатура, не декодируется, превышены байты или пиксели |
| 429 | `RATE_LIMITED` | Превышен лимит; заголовок `Retry-After` в секундах |
| 500 | `INTERNAL_ERROR` | Непредвиденная ошибка; подробности только в серверных логах по `request_id` |

### 1.3 Пагинация

Применяется ко всем списковым GET (`/materials`, `/buyer-requirements`, `/reservations`).

Query: `page` (int, по умолчанию 1, >= 1), `page_size` (int, по умолчанию 20, 1..100; больше 100 — 422).

```json
{ "items": [ ], "page": 1, "page_size": 20, "total": 134 }
```

Порядок по умолчанию стабильный: `created_at` по убыванию, затем `id` по возрастанию.

### 1.4 Ограничения частоты (429)

Ограничиваются: `POST /auth/login`, `POST /auth/register`, загрузка фото, `POST /ai/analyze`, `POST /ai/match`, `POST /optimization/run`, `POST /materials/{id}/publish`, `POST /materials/{id}/archive` (раздел 19, A19-2). Конкретные значения — конфигурация, не часть контракта (допущение). Ответ 429 содержит `Retry-After`.

### 1.5 Идемпотентность (`Idempotency-Key`)

- Заголовок `Idempotency-Key`: строка 8..128 символов `[A-Za-z0-9_-]`, как правило UUID, создаётся клиентом на одно намерение.
- Обязателен на: `POST /reservations`, `POST /materials/{id}/internal-use`, `POST /transactions/{id}/reuse-confirmation`. Без него — 422.
- Допустим на: `PATCH /reservations/{id}`. Дополнительно повтор действия безопасен и без ключа (см. 11.3).
- Область уникальности: `(user_id, operation, key)`. `operation` = метод + шаблон пути + целевой ID (+ `action` для PATCH заявки). Один и тот же ключ в разных операциях или у разных пользователей независим.
- Повтор с тем же ключом и тем же payload (канонизированное тело, отпечаток хранится на сервере) возвращает исходный ответ: тот же статус-код и тело, без повторных побочных эффектов, с заголовком `Idempotent-Replay: true`.
- Повтор с тем же ключом и иным payload — 409 `IDEMPOTENCY_KEY_REUSED`.
- Конкурентные запросы с одним ключом: уникальное ограничение в БД; второй запрос ждёт завершения первого и получает исходный результат. Вторая сделка/резерв/запись impact не создаётся.
- Сохраняются результаты успешных операций (2xx) и 409 по бизнес-правилам; 5xx не сохраняются, повтор выполняет операцию заново. Срок хранения ключей 24 часа (допущение).

## 2. Справочники (enum)

Значения строк — английские идентификаторы. Подписи на русском задаёт клиент.

| Enum | Значения |
| --- | --- |
| `Role` (регистрация) | `enterprise`, `buyer` |
| `ActivityType` | `garment_factory`, `workshop`, `recycler`, `other` (допущение) |
| `MaterialStatus` | `draft`, `available`, `reserved`, `partially_allocated`, `completed`, `archived` |
| `MaterialType` | `cotton`, `wool`, `linen`, `silk`, `synthetic`, `knit`, `denim`, `mixed`, `other` (допущение) |
| `MaterialCondition` | `unused`, `good`, `worn`, `damaged` (допущение) |
| `ReuseUse` (способ применения) | Совпадает с `ReuseType` из `docs/ai-schema.md` 2.4 (один словарь для AI и потребностей): `cleaning_rags`, `stuffing_filling`, `patchwork_crafts`, `accessories_small_goods`, `insulation_padding`, `recycling_shredding`, `other` (A19-15; заменяет прежний рабочий список) |
| `ReservationStatus` | `pending`, `confirmed`, `transferred`, `completed`, `cancelled` |
| `AnalysisStatus` | `pending`, `running`, `succeeded`, `failed`, `interrupted` |
| `SolverStatus` | `optimal`, `feasible`, `infeasible`, `timeout`, `error`, `heuristic` |
| `AllocationDirection` | `internal_use`, `sale`, `recycling` |

Статус партии вычисляется сервером по остаткам (`CLAUDE.md` §5) и не принимается от клиента.

## 3. Общие DTO

### 3.1 `Balance` (баланс массы партии)

| Поле | Тип |
| --- | --- |
| `total_kg` | string (decimal, масса) |
| `available_kg` | string |
| `held_kg` | string |
| `transferred_kg` | string |
| `internally_used_kg` | string |

Инвариант: `total_kg = available_kg + held_kg + transferred_kg + internally_used_kg`, каждая часть >= 0. `total_kg` не уменьшается при продаже.

### 3.2 `ContactInfo`

| Поле | Тип |
| --- | --- |
| `contact_name` | string или null |
| `contact_phone` | string или null |
| `contact_email` | string или null |

Контакты возвращаются только участникам соответствующей сделки (см. `ReservationOut.counterparty_contacts`) и владельцу организации. В публичных DTO их нет.

### 3.3 `OrganizationOut`

| Поле | Тип |
| --- | --- |
| `id` | uuid |
| `name` | string (1..200) |
| `city` | string (1..100) |
| `activity_type` | ActivityType |
| `contacts` | ContactInfo |
| `created_at` | datetime |

### 3.4 `UserOut`

| Поле | Тип |
| --- | --- |
| `id` | uuid |
| `email` | string |
| `role` | `enterprise` или `buyer` (или `admin` для служебных учётных записей) |
| `organization_id` | uuid |
| `active` | bool |

### 3.5 `MaterialImageOut`

Ссылок на файл нет; только ключ-метаданные. Временная ссылка выдаётся отдельно (8.5).

| Поле | Тип |
| --- | --- |
| `id` | uuid |
| `material_id` | uuid |
| `mime_type` | `image/jpeg`, `image/png` или `image/webp` |
| `size_bytes` | int |
| `width_px` | int |
| `height_px` | int |
| `sort_order` | int |
| `created_at` | datetime |

Object key в ответ не включается (внутренняя деталь хранилища).

### 3.6 `MaterialOut` (полная карточка, для владельца-enterprise)

| Поле | Тип | Примечание |
| --- | --- | --- |
| `id` | uuid | |
| `organization_id` | uuid | |
| `name` | string (1..200) | |
| `material_type` | MaterialType или null | null допустим только у черновика |
| `composition` | string (1..200) или null | Необязателен; неизвестный состав = null |
| `scrap_size` | string (1..100) или null | Размеры обрезков, свободный текст (допущение) |
| `condition` | MaterialCondition или null | |
| `price_per_kg` | string (деньги) или null | null = цена не задана, не ноль |
| `city` | string (1..100) или null | |
| `status` | MaterialStatus | Вычисляется сервером |
| `balance` | Balance | |
| `version` | int | >= 1, растёт при изменении входных характеристик (раздел 4) |
| `confirmed_at` | datetime или null | |
| `confirmed_by` | uuid или null | user id |
| `is_confirmation_current` | bool | true, если подтверждение относится к текущей `version` |
| `images` | MaterialImageOut[] | |
| `created_at` | datetime | |
| `updated_at` | datetime | |

### 3.7 `MaterialPublicOut` (для buyer; только опубликованные поля)

`id`, `organization_id`, `organization_name` (string), `name`, `material_type`, `composition` (или null), `scrap_size`, `condition`, `price_per_kg` (или null), `city`, `available_kg` (string), `status`, `images` (MaterialImageOut[], без ссылок), `version`, `created_at`.
Не включает: `confirmed_by`, `held_kg`, `transferred_kg`, `internally_used_kg`, `total_kg`, контакты, черновики, AI-предложения.

### 3.8 `BuyerRequirementOut`

| Поле | Тип | Примечание |
| --- | --- | --- |
| `id` | uuid | |
| `organization_id` | uuid | |
| `material_types` | MaterialType[] | Непустой |
| `conditions` | MaterialCondition[] | Непустой |
| `min_kg` | string (масса) | >= 0 |
| `max_kg` | string (масса) | > 0 |
| `remaining_demand_kg` | string (масса) | Меняется только сервером |
| `budget_per_kg` | string (деньги) или null | Скрыто от `enterprise` (допущение) |
| `city` | string (1..100) или null | |
| `uses` | ReuseUse[] | Пусто = любое применение допустимо |
| `active` | bool | |
| `created_at`, `updated_at` | datetime | |

Для `enterprise` поле `budget_per_kg` не возвращается (ключ отсутствует), контакты организации не возвращаются.

### 3.9 `TransactionOut`

| Поле | Тип | Примечание |
| --- | --- | --- |
| `id` | uuid | |
| `reservation_id` | uuid | Уникален: одна сделка на заявку |
| `transferred_kg` | string (масса) | Фактически переданные кг |
| `sale_amount_kgs` | string (деньги) или null | `transferred_kg` x согласованная цена; null, если цена не согласована |
| `transfer_confirmed_at` | datetime или null | Подтверждение продавцом |
| `receipt_confirmed_at` | datetime или null | Подтверждение покупателем |
| `confirmed_reuse_kg` | string (масса) | Сумма отдельных подтверждений использования |
| `created_at` | datetime | |

### 3.10 `ReservationOut`

| Поле | Тип | Примечание |
| --- | --- | --- |
| `id` | uuid | |
| `material_id` | uuid | |
| `material_name` | string | |
| `seller_organization_id` | uuid | |
| `buyer_organization_id` | uuid | |
| `requirement_id` | uuid или null | |
| `quantity_kg` | string (масса) | > 0 |
| `agreed_price_per_kg` | string (деньги) или null | |
| `status` | ReservationStatus | |
| `cancel_reason` | string (1..500) или null | |
| `cancelled_by_role` | `enterprise`, `buyer` или null | |
| `transaction` | TransactionOut или null | Появляется после `transfer` |
| `counterparty_contacts` | ContactInfo или null | Контакты другой стороны; только со статуса `confirmed` и далее (допущение) |
| `created_at`, `updated_at` | datetime | |

## 4. Версии (`version`) и устаревшие данные

- `materials.version` — целое, стартует с 1.
- `PATCH /materials/{id}` и `POST /materials/{id}/confirm` обязаны содержать `version` — значение, прочитанное клиентом. Если оно не равно текущему, возвращается 409 `VERSION_CONFLICT` с `details: {"current_version": 4}`, изменения не применяются. Сравнение и инкремент выполняются атомарно (условный UPDATE или блокировка строки).
- Инкремент `version` происходит при изменении входных характеристик: `material_type`, `composition`, `scrap_size`, `condition`, `city`, `total_kg`, а также при добавлении или удалении фото. Изменение только `name` и `price_per_kg` тоже увеличивает `version` (для оптимистичной блокировки), но не сбрасывает подтверждение (допущение).
- При изменении входных характеристик сервер сбрасывает подтверждение (`confirmed_at`, `confirmed_by` = null; `is_confirmation_current = false`). Если партия была опубликована и обязательств нет, она возвращается в `draft` (допущение). Ранее выполненные AI-анализы с меньшим `input_version` не могут подтвердить новую версию, сохранённые планы получают `is_stale = true`.
- Изменение `material_type`, `condition`, `city`, `total_kg` при активных обязательствах (резерв `pending` не считается обязательством; обязательство — `held_kg > 0` или `transferred_kg > 0`) запрещено: 409 `ACTIVE_OBLIGATIONS`. Снижение `total_kg` ниже суммы `held_kg + transferred_kg + internally_used_kg` также 409 `ACTIVE_OBLIGATIONS`. Изменение `total_kg` пересчитывает `available_kg = total_kg - held_kg - transferred_kg - internally_used_kg` на сервере.
- Остальные ресурсы (`buyer_requirements`, `organizations`) не имеют поля `version` (допущение: последняя запись побеждает).

## 5. Матрица доступа (кратко)

| Маршрут | enterprise | buyer | admin |
| --- | --- | --- | --- |
| auth, health | все | все | все |
| `/organizations/me` | своя | своя | своя |
| `GET /materials`, `GET /materials/{id}` | свои, любой статус | только опубликованные, `MaterialPublicOut` | не определено |
| `POST/PATCH /materials*`, images, confirm, internal-use, publish, archive | свои | 403 | не определено |
| `GET /buyer-requirements` | активные чужие без бюджета и контактов (допущение) | только свои | не определено |
| `POST/PATCH /buyer-requirements` | 403 | свои | не определено |
| `/ai/*`, `/optimization/*` | свои партии | 403 | не определено |
| `POST /reservations` | 403 | да | не определено |
| `GET /reservations` | где он продавец | где он покупатель | не определено |
| `PATCH /reservations/{id}` | confirm, cancel, transfer | cancel (своя), complete | не определено |
| `POST /transactions/{id}/reuse-confirmation` | 403 | покупатель сделки | не определено |
| `GET /analytics/summary` | своя | своя (сокращённая) | не определено |

## 6. Auth

### 6.1 POST /auth/register

Роль: аноним. Назначение: создать организацию и пользователя. Нельзя указать `admin`, нельзя присоединиться к существующей организации по ID (организация всегда создаётся новая).
Коды: 201, 409 (`EMAIL_ALREADY_REGISTERED`), 422, 429.

Request `RegisterIn`:

| Поле | Тип | Правила |
| --- | --- | --- |
| `email` | string | Валидный email, до 254 символов, регистр не учитывается |
| `password` | string | 10..128 символов (допущение) |
| `role` | `enterprise` или `buyer` | Другие значения, включая `admin`, — 422 |
| `organization` | object | см. ниже |
| `organization.name` | string | 1..200 |
| `organization.city` | string | 1..100 |
| `organization.activity_type` | ActivityType | |
| `organization.contacts` | ContactInfo | Необязательно |

Response 201 `UserWithOrganizationOut`: `{ "user": UserOut, "organization": OrganizationOut }`. Токен не выдаётся; вход отдельным запросом.

### 6.2 POST /auth/login

Роль: аноним. Назначение: проверить пароль, выдать токен (HS256, allowlist алгоритма, `exp`).
Коды: 200, 401 (`INVALID_CREDENTIALS`), 422, 429.

Request `LoginIn`: `email` (string), `password` (string).
Response 200 `TokenOut`:

| Поле | Тип |
| --- | --- |
| `access_token` | string |
| `token_type` | `"bearer"` |
| `expires_in` | int, секунды (3600, решение D-06, допущение по сроку) |
| `user` | UserOut |

Refresh-токенов в v1 нет; по истечении срока — повторный вход.

## 7. Организация

### 7.1 GET /organizations/me

Роль: любая аутентифицированная. Коды: 200, 401, 404.
Response 200: `OrganizationOut`.

### 7.2 PATCH /organizations/me

Роль: любая аутентифицированная (владелец своей организации). Коды: 200, 401, 422.
Request `OrganizationPatchIn` (все поля необязательны, минимум одно): `name`, `city`, `activity_type`, `contacts` (ContactInfo, заменяет целиком).
Смена `activity_type` на `recycler` допустима только для роли `buyer` (иначе 422).
Response 200: `OrganizationOut`.

## 8. Партии (materials)

### 8.1 GET /materials

Роль: `enterprise` (свои, все статусы), `buyer` (чужие опубликованные). Коды: 200, 401, 403 (admin не определён), 422.

Query:

| Параметр | Тип | Для кого | Описание |
| --- | --- | --- | --- |
| `page`, `page_size` | int | все | см. 1.3 |
| `status` | MaterialStatus | enterprise | Фильтр по статусу. У buyer игнорируется: всегда `available` и `partially_allocated` с `available_kg > 0` (допущение) |
| `material_type` | MaterialType, можно повторять | все | |
| `condition` | MaterialCondition, можно повторять | все | |
| `city` | string | все | Точное совпадение без учёта регистра |
| `min_available_kg` | string (масса) | все | `available_kg >= значение` |
| `max_price_per_kg` | string (деньги) | все | Партии без цены исключаются при заданном фильтре |
| `q` | string (1..100) | все | Поиск по `name`, без учёта регистра |
| `sort` | `created_at_desc` (по умолчанию), `created_at_asc`, `price_asc`, `available_kg_desc` | все | |

Response 200: `Page<MaterialOut>` для enterprise, `Page<MaterialPublicOut>` для buyer.

### 8.2 POST /materials

Роль: `enterprise`. Назначение: создать черновик. Фото не требуются.
Коды: 201, 401, 403, 422.

Request `MaterialCreateIn`:

| Поле | Тип | Обязательно |
| --- | --- | --- |
| `name` | string (1..200) | да |
| `material_type` | MaterialType | нет |
| `composition` | string (1..200) | нет |
| `scrap_size` | string (1..100) | нет |
| `condition` | MaterialCondition | нет |
| `price_per_kg` | string (деньги) | нет |
| `city` | string (1..100) | нет |
| `total_kg` | string (масса) | нет; по умолчанию `"0.000"`, у черновика допустим 0 |

Response 201: `MaterialOut` (`status = "draft"`, `version = 1`, `available_kg = total_kg`).

### 8.3 GET /materials/{id} и PATCH /materials/{id}

**GET.** Роль: enterprise-владелец (`MaterialOut`), buyer (`MaterialPublicOut`, только опубликованные). Чужой, неопубликованный или архивный объект — 404. Коды: 200, 401, 404.

**PATCH.** Роль: enterprise-владелец. Назначение: разрешённое изменение с проверкой `version`. Статус и остатки через PATCH менять нельзя.
Коды: 200, 401, 403, 404, 409 (`VERSION_CONFLICT`, `ACTIVE_OBLIGATIONS`), 422.

Request `MaterialPatchIn`: `version` (int, обязательно) и любые из `name`, `material_type`, `composition`, `scrap_size`, `condition`, `price_per_kg`, `city`, `total_kg` (null очищает необязательные поля). Минимум одно изменяемое поле. Правила версии и обязательств — раздел 4.
Response 200: `MaterialOut` с новым `version`.

### 8.4 POST /materials/{id}/images

Роль: enterprise-владелец. Назначение: загрузка фото; сервер проверяет и сохраняет в закрытый bucket под случайным ключом, в БД записывает только object key.
Коды: 201, 401, 403, 404, 409 (`IMAGE_LIMIT_REACHED`), 422 (`UNSUPPORTED_IMAGE`), 429.

Request: `multipart/form-data`, одно поле `file` (бинарный). Опционально поле `sort_order` (int >= 0; по умолчанию в конец).
Ограничения (из `CLAUDE.md` §11): JPEG/PNG/WebP по сигнатуре и успешному декодированию, до 10 MB, до 20 мегапикселей после декодирования, до 5 фото на партию. Имя файла клиента игнорируется.
Response 201: `ImageUploadOut`: `{ "image": MaterialImageOut, "material_version": int }`. Загрузка увеличивает `version` (раздел 4).

### 8.5 GET /materials/{id}/images/{image_id}/url (дополнительный)

Роль: enterprise-владелец; buyer — только для опубликованной партии. Назначение: выдать короткоживущую подписанную ссылку на фото после проверки доступа (в БД постоянных URL нет). Коды: 200, 401, 404 (в том числе если `image_id` принадлежит другой партии).
Response 200 `SignedUrlOut`: `url` (string), `expires_at` (datetime). Срок жизни — минуты (значение в конфигурации). Ссылку нельзя логировать и сохранять.

### 8.6 POST /materials/{id}/confirm

Роль: enterprise-владелец. Назначение: человек подтверждает текущие характеристики; AI не подтверждает ничего сам.
Коды: 200, 401, 403, 404, 409 (`VERSION_CONFLICT`, `PRECONDITION_FAILED`), 422.

Request `MaterialConfirmIn`:

| Поле | Тип | Описание |
| --- | --- | --- |
| `version` | int | Версия, которую человек видел |
| `analysis_id` | uuid или null | Необязательно. Если задан: анализ должен принадлежать этой партии, иметь статус `succeeded` и `input_version == version`, иначе 409 `PRECONDITION_FAILED`. AI-предложения не копируются в характеристики, подтверждаются значения полей партии |

Подтверждение допускает неизвестный состав (`composition = null`). Подтверждается строго текущая `version`; повтор для уже подтверждённой текущей версии возвращает 200 без изменений.
Response 200: `MaterialOut` (`confirmed_at`, `confirmed_by` заполнены).

### 8.7 POST /materials/{id}/publish (дополнительный)

Роль: enterprise-владелец. Назначение: перевести `draft` в `available`. Без отдельного маршрута пройти шаг 2 сценария нельзя: произвольный PATCH статуса запрещён.
Условия публикации: >= 1 фото; `material_type`, `condition`, `city` заданы; `total_kg > 0`; подтверждение актуально (`is_confirmation_current = true`). Иначе 422 `PUBLISH_REQUIREMENTS_NOT_MET` с `details.missing`, например `["images", "confirmation"]`.
Коды: 200, 401, 403, 404, 409 (`VERSION_CONFLICT`, `INVALID_TRANSITION`), 422, 429. Полный контракт и правила повтора: раздел 19 (приоритет у 19; повтор publish уже опубликованной партии - 200, а не 409).
Request: `{ "version": int }`; несовпадение — 409 `VERSION_CONFLICT`.
Response 200: `MaterialOut`.

### 8.8 POST /materials/{id}/archive (дополнительный)

Роль: enterprise-владелец. Назначение: скрыть партию. Допустимо при `held_kg = 0` (активных резервов нет), иначе 409 `ACTIVE_OBLIGATIONS`. Статус `completed` и `archived` ставятся только сервером.
Коды: 200, 401, 403, 404, 409, 429. Request: `{ "version": int }`. Response 200: `MaterialOut`. Полный контракт: раздел 19.

### 8.9 POST /materials/{id}/internal-use

Роль: enterprise-владелец. Назначение: атомарно зафиксировать фактическое внутреннее использование: `available_kg -= quantity_kg`, `internally_used_kg += quantity_kg`, создаётся `impact_record`. Блокировка строки партии, повторная проверка остатка внутри транзакции.
Заголовок: `Idempotency-Key` (обязателен).
Коды: 201, 401, 403, 404, 409 (`INSUFFICIENT_STOCK`, `IDEMPOTENCY_KEY_REUSED`), 422.

Request `InternalUseIn`:

| Поле | Тип | Правила |
| --- | --- | --- |
| `quantity_kg` | string (масса) | > 0 |
| `basis` | string (1..500) | Основание, например «пошив образцов» |
| `used_on` | date (`YYYY-MM-DD`) или null | По умолчанию дата запроса (UTC) |

Response 201 `InternalUseOut`: `{ "impact_record_id": uuid, "material": MaterialOut }`. Повтор с тем же ключом и payload — исходный ответ (201 с `Idempotent-Replay: true`).

## 9. Потребности покупателя

### 9.1 GET /buyer-requirements

Роль: `buyer` — свои (любая активность); `enterprise` — только `active = true` чужие, без `budget_per_kg` и контактов (допущение). Коды: 200, 401, 422.
Query: `page`, `page_size`; `active` (bool, только buyer); `material_type` (MaterialType); `city` (string).
Response 200: `Page<BuyerRequirementOut>`.

### 9.2 POST /buyer-requirements

Роль: `buyer`. Коды: 201, 401, 403, 422.

Request `BuyerRequirementCreateIn`:

| Поле | Тип | Правила |
| --- | --- | --- |
| `material_types` | MaterialType[] | 1..10, без дублей |
| `conditions` | MaterialCondition[] | 1..4, без дублей |
| `min_kg` | string (масса) | >= 0, `min_kg <= max_kg` |
| `max_kg` | string (масса) | > 0 |
| `budget_per_kg` | string (деньги) или null | >= 0; null = бюджет не задан |
| `city` | string (1..100) или null | |
| `uses` | ReuseUse[] | 0..6; пусто = любое |

Сервер ставит `remaining_demand_kg = max_kg`, `active = true`.
Response 201: `BuyerRequirementOut`.

### 9.3 PATCH /buyer-requirements/{id}

Роль: `buyer`, владелец. Чужая потребность — 404. Коды: 200, 401, 403, 404, 409 (`DEMAND_EXCEEDED`), 422.
Request `BuyerRequirementPatchIn`: любые из полей `POST` плюс `active` (bool); минимум одно поле. `remaining_demand_kg` напрямую менять нельзя.
При изменении `max_kg` сервер пересчитывает `remaining_demand_kg = max_kg - (kg по активным резервам и переданным по этой потребности)`; если результат < 0 — 409 `DEMAND_EXCEEDED` (допущение).
Response 200: `BuyerRequirementOut`.

## 10. AI-анализ и matching

### 10.1 POST /ai/analyze

Роль: enterprise-владелец партии. Назначение: поставить анализ в очередь; job сохраняется в БД до запуска (решение D-07).
Коды: 202, 401, 403, 404, 409 (`PRECONDITION_FAILED` — нет фото), 422, 429.

Request `AnalyzeIn`: `{ "material_id": uuid }`.
Response 202 `AnalysisAcceptedOut`: `{ "analysis_id": uuid, "status": "pending", "input_version": int }`. Повторный запрос, пока для той же партии и той же `input_version` есть задача `pending`/`running`, возвращает 202 с существующим `analysis_id` (второй задачи нет; A-AI-6). Нет фото - 409 `PRECONDITION_FAILED`, `details.reason = "NO_IMAGES"`. Подробности: `docs/ai-schema.md` раздел 11.
Заголовок `Location: /ai/analyses/{analysis_id}`.

### 10.2 GET /ai/analyses/{id}

Роль: enterprise-владелец партии анализа. Чужой анализ — 404. Коды: 200, 401, 403, 404.
Response 200 `AnalysisOut` (предварительно, окончательная схема — CON-02):

| Поле | Тип | Примечание |
| --- | --- | --- |
| `id` | uuid | |
| `material_id` | uuid | |
| `status` | AnalysisStatus | `failed`/`interrupted` — недоступность AI; ручной ввод и подтверждение продолжают работать |
| `input_version` | int | Версия партии на момент запуска |
| `is_current` | bool | `input_version == текущая version партии` |
| `mode` | `live`/`mock`/`fallback` или null | null до `succeeded` (17.13) |
| `requires_confirmation` | `true` | Всегда, для любого статуса |
| `schema_version` | string или null | `"1.0"` |
| `provider` | string или null | Из конфигурации; для mock значение явно `mock` |
| `model` | string или null | |
| `result` | `VisionModelOutput` или null | Только при `succeeded` и прошедшем валидацию; форма в 17.9 и `docs/ai-schema.md` 2.1-2.3 |
| `error_code` | string или null | Один из 9 кодов (17.9), только при `failed`/`interrupted`, без текста провайдера |
| `confirmed_at`, `confirmed_by` | datetime или null, uuid или null | |
| `created_at`, `updated_at` | datetime | |

`result` = `VisionModelOutput` (подробно в 17.9; источник - `docs/ai-schema.md` раздел 11). Состав, вес, прочность, безопасность и химические свойства по фото не заполняются. Результат - предложение; характеристики партии он не меняет.

### 10.3 POST /ai/match

Роль: enterprise-владелец партии. Назначение: детерминированный подбор потребностей, без LLM; та же функция совместимости, что у оптимизатора. Использует только подтверждённые актуальные характеристики.
Коды: 200, 401, 403, 404, 409 (`PRECONDITION_FAILED` — характеристики не подтверждены или подтверждение устарело), 422, 429.

Request `MatchIn`: `{ "material_id": uuid, "limit": int }` (`limit` 1..50, по умолчанию 20).
Response 200 `MatchOut` (предварительно, окончательная форма — CON-03):

| Поле | Тип |
| --- | --- |
| `material_id` | uuid |
| `material_version` | int |
| `rules_version` | string |
| `matches` | MatchItem[] |
| `excluded` | ExcludedItem[] |

`MatchItem`: `requirement_id` (uuid), `organization_name` (string), `score` (int 0..100), `components` (`{city: int, use: int, coverage: int}`), `reasons` (string[], по-русски), `possible_kg` (string, масса), `city` (string или null). Сортировка: `score` по убыванию, затем `requirement_id` по возрастанию.
`ExcludedItem`: `requirement_id` (uuid), `reason_codes` (string[]), `reasons` (string[]). Неизвестные критичные характеристики не считаются совпадением и попадают в исключённые.
Бюджет и контакты покупателя в ответе не раскрываются.

## 11. Оптимизация

### 11.1 POST /optimization/run

Роль: enterprise. Назначение: рассчитать и сохранить план для выбранных партий. План — рекомендация, остатки, статусы и спрос не меняет. Расчёт выполняется синхронно вне event loop с лимитом времени (конфигурация `OPTIMIZATION_TIMEOUT_SECONDS`).
Коды: 201, 401, 403, 404 (любая партия не своя), 409 (`PRECONDITION_FAILED` — партия без актуального подтверждения), 422, 429.

Request `OptimizationRunIn` (предварительно, CON-03):

| Поле | Тип | Правила |
| --- | --- | --- |
| `material_ids` | uuid[] | 1..20 (лимит, допущение), без дублей |
| `assumptions` | object или null | Явные входные допущения; отсутствующее значение не заменяется нулём, вариант без оценки исключается с объяснением |
| `assumptions.internal_use` | `{value_per_kg: money, cost_per_kg: money, capacity_kg: mass}` или null | Оценка экономии при внутреннем использовании; прогноз, не выручка |
| `assumptions.recycling` | `{value_per_kg: money, cost_per_kg: money, capacity_kg: mass}` или null | |
| `assumptions.delivery_cost_per_kg` | string (деньги) или null | Явное предположение, одинаковое в baseline и оптимизации |

Response 201 `OptimizationRunOut`:

| Поле | Тип | Примечание |
| --- | --- | --- |
| `id` | uuid | |
| `status` | SolverStatus | `feasible` и `heuristic` не называются доказанным оптимумом |
| `method` | string | Например `scipy_milp` |
| `algorithm_version` | string | |
| `rules_version` | string | Версия правил совместимости/скоринга |
| `label` | `"expected"` | Прогноз, не факт |
| `objective_kgs` | string (деньги) | Ожидаемая чистая ценность |
| `baseline` | `{method: string, value_kgs: string}` | Допустимый baseline на тех же входах |
| `delta_vs_baseline_kgs` | string (деньги, может быть отрицательным) | Знак разрешён только здесь и в `net_value_kgs`; формат `-12.00` |
| `allocations` | AllocationOut[] | |
| `remainder` | `{material_id: uuid, remainder_kg: string}[]` | Нераспределённый остаток явно |
| `input_versions` | `{material_id: uuid, version: int}[]` | Снимок версий |
| `assumptions` | object | Входные допущения с пометкой происхождения |
| `solve_time_ms` | int | |
| `is_stale` | bool | true, если версия любой партии изменилась; тогда предлагается пересчёт |
| `created_at` | datetime | |

`AllocationOut`: `material_id` (uuid), `direction` (AllocationDirection), `requirement_id` (uuid или null), `quantity_kg` (string), `unit_value_kgs` (string), `unit_cost_kgs` (string), `net_value_kgs` (string, допускает знак минус), `explanation` (string, по-русски).

### 11.2 GET /optimization/runs/{id}

Роль: enterprise, владелец плана. Чужой — 404. Коды: 200, 401, 403, 404.
Response 200: `OptimizationRunOut` (`is_stale` вычисляется при чтении).

## 12. Заявки, сделки

### 12.1 Машина состояний заявки

```
pending ──confirm──> confirmed ──transfer──> transferred ──complete──> completed
pending ──cancel───> cancelled
confirmed ──cancel─> cancelled
```

- `pending` запас не удерживает.
- `confirm`: атомарно `available_kg -= quantity_kg`, `held_kg += quantity_kg`; у потребности `remaining_demand_kg -= quantity_kg`. Блокировки `SELECT ... FOR UPDATE` в порядке: `materials`, затем `buyer_requirements` (решение D-08); проверки доступности и спроса повторяются внутри транзакции. Нехватка массы — 409 `INSUFFICIENT_STOCK`, спроса — 409 `DEMAND_EXCEEDED`.
- `cancel` из `confirmed`: `held_kg -= quantity_kg`, `available_kg += quantity_kg`, спрос потребности возвращается.
- `transfer`: удержание переходит в фактическую передачу (`held_kg -= x`, `transferred_kg += x`), создаётся `transactions` (UNIQUE по `reservation_id`). Если `transferred_kg < quantity_kg`, разница возвращается в `available_kg`, а спрос потребности возвращается на эту разницу (допущение).
- `complete`: покупатель подтверждает получение; `receipt_confirmed_at` заполняется. Выручка в аналитике учитывается именно на этом шаге.
- Из `transferred`, `completed`, `cancelled` отмена невозможна (409 `INVALID_TRANSITION`).

### 12.2 POST /reservations

Роль: `buyer`. Назначение: создать заявку (`pending`) на `material_id`. Запас не удерживается.
Заголовок: `Idempotency-Key` (обязателен).
Коды: 201, 401, 403, 404 (партия не опубликована или requirement чужой), 409 (`INSUFFICIENT_STOCK`, `IDEMPOTENCY_KEY_REUSED`), 422.

Request `ReservationCreateIn`:

| Поле | Тип | Правила |
| --- | --- | --- |
| `material_id` | uuid | Опубликованная партия |
| `requirement_id` | uuid или null | Своя активная потребность |
| `quantity_kg` | string (масса) | > 0; не более текущего `available_kg` (проверка без блокировки; окончательная при `confirm`); если указан `requirement_id`, то не менее `min_kg` потребности |
| `agreed_price_per_kg` | string (деньги) или null | Если null, берётся `price_per_kg` партии; если нет и её — 422 (цена не подставляется нулём) |

Response 201: `ReservationOut` (`status = "pending"`).
Повтор с тем же ключом и payload — исходный 201 с `Idempotent-Replay: true`.

### 12.3 GET /reservations

Роль: `enterprise` (где он продавец), `buyer` (где он покупатель). Коды: 200, 401, 403, 422.
Query: `page`, `page_size`; `status` (ReservationStatus, можно повторять); `material_id` (uuid).
Response 200: `Page<ReservationOut>`.

### 12.4 PATCH /reservations/{id}

Роль и действия:

| `action` | Кто | Из статуса | В статус |
| --- | --- | --- | --- |
| `confirm` | enterprise-продавец | `pending` | `confirmed` |
| `cancel` | enterprise-продавец (отказ, `reason` обязателен); buyer-покупатель своей заявки (допущение) | `pending`, `confirmed` | `cancelled` |
| `transfer` | enterprise-продавец | `confirmed` | `transferred` |
| `complete` | buyer-покупатель | `transferred` | `completed` |

Заголовок: `Idempotency-Key` (необязателен, рекомендуется).
Коды: 200, 401, 403 (роль не подходит действию), 404 (чужая заявка), 409 (`INSUFFICIENT_STOCK`, `DEMAND_EXCEEDED`, `INVALID_TRANSITION`, `IDEMPOTENCY_KEY_REUSED`), 422.

Request `ReservationActionIn`:

| Поле | Тип | Правила |
| --- | --- | --- |
| `action` | `confirm`, `cancel`, `transfer`, `complete` | Произвольный `status` в теле запрещён (422) |
| `reason` | string (1..500) или null | Обязателен для `cancel` продавцом; иначе игнорируется |
| `transferred_kg` | string (масса) или null | Только для `transfer`: 0 < значение <= `quantity_kg`; по умолчанию `quantity_kg` |

Response 200: `ReservationOut`.
Повтор действия, уже приведшего заявку в целевой статус (то же `action`), возвращает 200 с текущим состоянием, без побочных эффектов; второй `transaction` или `impact_record` не создаётся. Действие, не допустимое из текущего статуса и не являющееся повтором, — 409 `INVALID_TRANSITION`.

### 12.5 POST /transactions/{id}/reuse-confirmation

Роль: `buyer`, покупатель сделки. Чужая сделка — 404. Назначение: отдельное подтверждение фактического использования переданной массы; создаёт `impact_record`.
Заголовок: `Idempotency-Key` (обязателен).
Условие: заявка в статусе `completed` (допущение). Сумма подтверждений не может превышать `transferred_kg` сделки; превышение — 422 `VALIDATION_ERROR` с `details.max_reusable_kg`.
Коды: 201, 401, 403, 404, 409 (`INVALID_TRANSITION` — заявка не `completed`, `IDEMPOTENCY_KEY_REUSED`), 422.

Request `ReuseConfirmationIn`:

| Поле | Тип | Правила |
| --- | --- | --- |
| `reused_kg` | string (масса) | > 0 |
| `basis` | string (1..500) | Основание подтверждения |
| `reused_on` | date или null | По умолчанию дата запроса (UTC) |

Response 201 `ReuseConfirmationOut`: `{ "impact_record_id": uuid, "transaction": TransactionOut }`. Передача и получение не считаются подтверждением использования.

## 13. Аналитика

### 13.1 GET /analytics/summary

Роль: `enterprise` и `buyer`; каждый видит только свою организацию. Коды: 200, 401, 403.
Query: нет (диапазон дат в v1 не поддерживается).

Response 200 `AnalyticsSummaryOut` для `enterprise`:

| Поле | Тип | Определение (`CLAUDE.md` §10) |
| --- | --- | --- |
| `role_view` | `"enterprise"` | |
| `registered_kg` | string | Сумма `total_kg` партий, не повторно по событиям (черновики не исключаются, архивные включаются: допущение) |
| `available_kg` | string | Свободный фактический остаток |
| `distributed_kg` | string | Активный резерв (`held_kg`) + переданная масса (`transferred_kg`), без двойного счёта |
| `internally_used_kg` | string | Внутреннее использование (отдельно от `distributed_kg`) |
| `confirmed_reuse_kg` | string | Сумма отдельных подтверждений использования |
| `revenue_kgs` | string | Сумма `sale_amount_kgs` по заявкам в статусе `completed`; передача, резерв, внутренняя экономия и прогноз не входят |
| `allocation_efficiency_pct` | string | `distributed_kg / registered_kg x 100`; при `registered_kg = 0` — `"0.00"` |
| `forecast` | объект или null | Последний сохранённый план |
| `forecast.run_id` | uuid | |
| `forecast.label` | `"expected"` | Прогноз |
| `forecast.expected_net_value_kgs` | string | Не выручка |
| `forecast.expected_remainder_kg` | string | Прогнозный остаток плана; отдельно от `available_kg` |
| `forecast.is_stale` | bool | |
| `is_demo` | bool | true, если включён `DEMO_MODE` / данные демонстрационные; клиент показывает метку «демо» |
| `generated_at` | datetime | |

Для `buyer` (сокращённая версия, допущение): `role_view = "buyer"`, `received_kg` (переданное в сделках со статусом `transferred` и `completed`), `confirmed_reuse_kg`, `spent_kgs` (сумма `sale_amount_kgs` по `completed`), `active_reservations_count` (int), `is_demo`, `generated_at`.
Пустой набор данных возвращает нули (`"0.000"`, `"0.00"`) и `forecast = null`. CO2 и экологические показатели не возвращаются.

## 14. Health

### 14.1 GET /health

Без авторизации. Коды: 200. Response 200: `{ "status": "ok" }`. Версий, строк подключения и других данных конфигурации нет.

## 15. Сводка маршрутов

| Метод и путь | Роль | Коды |
| --- | --- | --- |
| POST `/auth/register` | аноним | 201, 409, 422, 429 |
| POST `/auth/login` | аноним | 200, 401, 422, 429 |
| GET `/organizations/me` | любая | 200, 401, 404 |
| PATCH `/organizations/me` | любая | 200, 401, 422 |
| GET `/materials` | enterprise, buyer | 200, 401, 403, 422 |
| POST `/materials` | enterprise | 201, 401, 403, 422 |
| GET `/materials/{id}` | enterprise, buyer | 200, 401, 404 |
| PATCH `/materials/{id}` | enterprise | 200, 401, 403, 404, 409, 422 |
| POST `/materials/{id}/images` | enterprise | 201, 401, 403, 404, 409, 422, 429 |
| GET `/materials/{id}/images/{image_id}/url` (дополнительный) | enterprise, buyer | 200, 401, 404 |
| POST `/materials/{id}/confirm` | enterprise | 200, 401, 403, 404, 409, 422 |
| POST `/materials/{id}/publish` (дополнительный) | enterprise | 200, 401, 403, 404, 409, 422, 429 |
| POST `/materials/{id}/archive` (дополнительный) | enterprise | 200, 401, 403, 404, 409, 429 |
| POST `/materials/{id}/internal-use` | enterprise | 201, 401, 403, 404, 409, 422 |
| GET `/buyer-requirements` | buyer, enterprise | 200, 401, 422 |
| POST `/buyer-requirements` | buyer | 201, 401, 403, 422 |
| PATCH `/buyer-requirements/{id}` | buyer | 200, 401, 403, 404, 409, 422 |
| POST `/ai/analyze` | enterprise | 202, 401, 403, 404, 409, 422, 429 |
| GET `/ai/analyses/{id}` | enterprise | 200, 401, 403, 404 |
| POST `/ai/match` | enterprise | 200, 401, 403, 404, 409, 422, 429 |
| POST `/optimization/run` | enterprise | 201, 401, 403, 404, 409, 422, 429 |
| GET `/optimization/runs/{id}` | enterprise | 200, 401, 403, 404 |
| POST `/reservations` | buyer | 201, 401, 403, 404, 409, 422 |
| GET `/reservations` | enterprise, buyer | 200, 401, 403, 422 |
| PATCH `/reservations/{id}` | enterprise, buyer | 200, 401, 403, 404, 409, 422 |
| POST `/transactions/{id}/reuse-confirmation` | buyer | 201, 401, 403, 404, 409, 422 |
| GET `/analytics/summary` | enterprise, buyer | 200, 401, 403 |
| GET `/health` | аноним | 200 |

## 16. Открытые вопросы (допущения, не покрытые CLAUDE.md)

Все пункты ниже — допущения; они действуют до решения оркестратора или пользователя.

1. Допущение: словари `ActivityType`, `MaterialType`, `MaterialCondition`, `ReuseUse` (раздел 2) — рабочие значения, ТЗ их не задаёт. Окончательный `ReuseUse` определяют CON-02/CON-03.
2. Допущение: `scrap_size` — свободный текст, не структура (ТЗ называет «размеры обрезков» без формата).
3. Допущение: добавлены маршруты `publish`, `archive` и `GET .../images/{image_id}/url`. Первый нужен, потому что произвольный PATCH статуса запрещён, а публикация обязательна для пути; третий — чтобы показать фото без постоянных URL. Альтернатива для `archive` — отложить после MVP.
4. Допущение: изменение входных характеристик возвращает опубликованную партию в `draft`, если нет обязательств; при обязательствах — 409 `ACTIVE_OBLIGATIONS`. Что считать «ключевыми характеристиками» для сброса подтверждения — решение продукта (здесь: type, composition, scrap_size, condition, city, total_kg, фото).
5. Допущение: `enterprise` видит чужие активные потребности без `budget_per_kg` и контактов; бюджет используется только внутри matching/optimizer на сервере.
6. Допущение: buyer видит партии в статусах `available` и `partially_allocated` при `available_kg > 0`; `reserved` скрыт от каталога.
7. Допущение: покупатель может отменить свою заявку в `pending`/`confirmed`; ТЗ прямо говорит только о подтверждении и отмене со стороны `enterprise`.
8. Допущение: частичная передача (`transferred_kg < quantity_kg`) возвращает разницу в доступный остаток и в спрос потребности.
9. Допущение: `reuse-confirmation` допустим только после `complete`; превышение переданной массы — 422 с `details.max_reusable_kg`.
10. Допущение: `buyer_requirements` и `organizations` без `version` (последняя запись побеждает); при смене `max_kg` пересчёт `remaining_demand_kg` по формуле из 9.3.
11. Допущение: контакты контрагента открываются со статуса `confirmed` (ТЗ: «участникам соответствующей сделки»).
12. Допущение: срок access token 60 минут, refresh-токенов нет (D-06); пароль 10..128 символов; срок хранения ключей идемпотентности 24 часа; лимиты 429 задаются конфигурацией.
13. Допущение: код 413/415 не используются, ошибки загрузки идут как 422 `UNSUPPORTED_IMAGE`, чтобы остаться в наборе кодов ТЗ. Может быть пересмотрено.
14. Допущение: повтор регистрации с занятым email возвращает 409 `EMAIL_ALREADY_REGISTERED` (допускает перебор email; смягчение — после MVP).
15. Допущение: роль `admin` и модерационные маршруты в v1 не описаны; поведение admin на публичных маршрутах не определено и по умолчанию 403.
16. Допущение: `registered_kg` включает архивные партии и черновики; ТЗ формулировку «зарегистрированная масса» не уточняет. Аналитика `buyer` — сокращённая, состав полей не из ТЗ.
17. Допущение: форма запроса `/optimization/run` (поле `assumptions`) предварительная; ТЗ требует модель внутреннего использования и переработки с совместимостью и ёмкостью, но не задаёт источник цен и ёмкостей. Ждёт CON-03 и реестра допущений (D-10).
18. Допущение (заменено A17-30): `AnalysisResult` был предварительным; теперь `VisionModelOutput`. Дополнительно открыто: авто-повтор временных ошибок AI не меняет контракт, клиент видит только итоговый статус.
19. Не покрыто: удаление фото (`DELETE` в ТЗ нет); замена фото = загрузка нового и (после MVP) удаление старого. Лимит 5 фото тогда достигается без возможности убрать лишнее.
20. Не покрыто: список планов `GET /optimization/runs`, `GET /reservations/{id}`, `GET /buyer-requirements/{id}`, `GET /transactions/{id}` — в ТЗ нет, не добавлены. Клиент получает сделку внутри `ReservationOut.transaction`.

---

## 17. Frozen for mobile Phase 1

Статус: заморозка контракта для мобильного клиента (Flutter), сценарий P0: регистрация и вход, организация, партия, фото, AI-анализ, подтверждение человеком, matching, оптимизация, резерв.
Дата записи: 2026-11-07. Владелец: backend-engineer. Требует утверждения оркестратором (CON-01 ещё не утверждён).

**Состояние реализации: НИЧЕГО НЕ РЕАЛИЗОВАНО.** BE-01 (skeleton) в статусе todo: нет ни маршрутов, ни моделей, ни миграций. Всё ниже - контракт, а не описание работающего кода. Клиент пишет против него с моками (`DEPENDENCIES.md` §6); интеграция - только после BE-01..BE-03 и проверки по OpenAPI.

Правила заморозки:
- Разделы 1-4 (общие правила, enum, общие DTO, версии) входят в заморозку целиком; ниже они уточняются, не заменяются.
- Меняется только через оркестратора. Добавление необязательного поля в ответ - совместимое изменение; переименование, удаление, смена типа или кода ошибки - несовместимое, требует согласования с flutter-developer.
- Метка «допущение» - решения, которых нет в `CLAUDE.md`. Новые допущения этого раздела пронумерованы A17-n и перечислены в 17.15.
- Клиент обязан игнорировать неизвестные поля ответа (ответ может расширяться), но сам не отправляет лишних полей (иначе 422).

### 17.0 Сквозной порядок вызовов P0 (мобильный клиент)

```
register -> login -> GET /organizations/me (опц. PATCH)
POST /materials (version=1)
POST /materials/{id}/images  x N      (каждая загрузка version+1; брать material_version из ответа)
POST /ai/analyze              -> 202, input_version = текущая version
GET  /ai/analyses/{id}        -> опрос до succeeded | failed | interrupted
POST /materials/{id}/confirm  {version, analysis_id?}   (version не меняется, допущение A17-1)
POST /materials/{id}/publish  {version}                  (дополнительный маршрут, см. раздел 8.7)
POST /ai/match                -> 200
POST /optimization/run        -> 201
GET  /optimization/runs/{id}  -> 200 (повторное чтение, is_stale)
buyer: GET /materials -> POST /reservations (Idempotency-Key) -> 201 pending
```

Практические правила клиента:
- После register токена нет; вход отдельным `POST /auth/login`. Токен хранить в защищённом хранилище устройства (Keychain/Keystore), не в логах.
- При 401 `UNAUTHENTICATED` на любом маршруте - стереть токен и перейти на экран входа. Refresh-токенов нет, `expires_in` = 3600 с.
- Версия для следующего изменения всегда берётся из последнего ответа (`MaterialOut.version` или `ImageUploadOut.material_version`). Загрузка фото увеличивает версию; `confirm` после загрузки с устаревшей версией даст 409 `VERSION_CONFLICT`.
- Опрос анализа: интервал 2 с, потолок 90 с (допущение A17-2), затем показать «анализ не завершён», ручной ввод и подтверждение остаются доступны.
- План оптимизации и matching не резервируют ничего. Резерв создаёт только покупатель (17.14).

### 17.1 Типы и форматы полей (напоминание для DTO в Dart)

| Тип в таблицах | Формат | Dart |
| --- | --- | --- |
| `uuid` | каноническая строка | `String` |
| `datetime` | UTC, `2026-11-07T10:15:30Z` | `DateTime` (парсинг как UTC) |
| `mass` | строка decimal, до 3 знаков, >= 0 | `Decimal`/`String`, не `double` |
| `money` | строка decimal, до 2 знаков, >= 0 (исключение: `net_value_kgs`, `delta_vs_baseline_kgs` могут быть со знаком минус) | то же |
| `int` | JSON число без дробной части | `int` |
| `enum` | строка из раздела 2 | `enum` с fallback `unknown` на неизвестное значение |

Число JSON вместо строки для mass/money - 422. Для всех «Обяз.» ниже: «да» - поле должно присутствовать и не быть null; «нет» - можно опустить; «нет, null» - можно передать null.

### 17.2 POST /auth/register

Роль: аноним. Коды: 201, 409 `EMAIL_ALREADY_REGISTERED`, 422 `VALIDATION_ERROR`, 429 `RATE_LIMITED`.

| Поле запроса | Тип | Обяз. | Правила |
| --- | --- | --- | --- |
| `email` | string | да | валидный email, до 254, регистр не учитывается |
| `password` | string | да | 10..128 символов (A17-3) |
| `role` | enum `enterprise`/`buyer` | да | `admin` и прочее - 422 |
| `organization.name` | string | да | 1..200 |
| `organization.city` | string | да | 1..100 |
| `organization.activity_type` | enum ActivityType | да | переработчик: role=`buyer` + `recycler` |
| `organization.contacts` | ContactInfo | нет | поля `contact_name`, `contact_phone`, `contact_email` (все nullable, строки 1..200; формат телефона не проверяется, A17-4) |

```json
{
  "email": "seller@example.test",
  "password": "correct-horse-battery",
  "role": "enterprise",
  "organization": {
    "name": "Демо Швейная Фабрика",
    "city": "Бишкек",
    "activity_type": "garment_factory",
    "contacts": { "contact_name": "Тест Тестович", "contact_phone": null, "contact_email": null }
  }
}
```

Ответ 201 `UserWithOrganizationOut` (токена нет):

```json
{
  "user": { "id": "5d1c0f0e-3b7a-4a55-9a53-0a7f2a9d1c01", "email": "seller@example.test", "role": "enterprise",
            "organization_id": "b2a8f3d4-6c1e-4f0a-8d77-4c5f7a0e9b22", "active": true },
  "organization": { "id": "b2a8f3d4-6c1e-4f0a-8d77-4c5f7a0e9b22", "name": "Демо Швейная Фабрика", "city": "Бишкек",
                    "activity_type": "garment_factory",
                    "contacts": { "contact_name": "Тест Тестович", "contact_phone": null, "contact_email": null },
                    "created_at": "2026-11-07T10:15:30Z" }
}
```

Ошибки: 422 (слабый пароль, `role=admin`, лишнее поле, плохой email), 409 (email занят; допущение A17-5: допускает перебор email).

### 17.3 POST /auth/login

Роль: аноним. Коды: 200, 401 `INVALID_CREDENTIALS` (одно сообщение на неверный email и пароль), 422, 429 (с `Retry-After`).

Запрос: `email` (string, да), `password` (string, да).

```json
{ "email": "seller@example.test", "password": "correct-horse-battery" }
```

Ответ 200 `TokenOut`:

```json
{ "access_token": "<jwt>", "token_type": "bearer", "expires_in": 3600,
  "user": { "id": "5d1c0f0e-3b7a-4a55-9a53-0a7f2a9d1c01", "email": "seller@example.test", "role": "enterprise",
            "organization_id": "b2a8f3d4-6c1e-4f0a-8d77-4c5f7a0e9b22", "active": true } }
```

| Поле ответа | Тип | Обяз. |
| --- | --- | --- |
| `access_token` | string | да |
| `token_type` | `"bearer"` | да |
| `expires_in` | int (секунды) | да |
| `user` | UserOut | да |

Неактивный пользователь получает тот же `INVALID_CREDENTIALS` (A17-6, не раскрывать состояние учётной записи).

### 17.4 GET и PATCH /organizations/me

Роль: любая аутентифицированная. GET: 200, 401, 404. PATCH: 200, 401, 422.

GET 200 - `OrganizationOut` (как в 17.2: `id`, `name`, `city`, `activity_type`, `contacts`, `created_at`).

PATCH запрос `OrganizationPatchIn` (минимум одно поле, иначе 422):

| Поле | Тип | Обяз. | Примечание |
| --- | --- | --- | --- |
| `name` | string 1..200 | нет | |
| `city` | string 1..100 | нет | |
| `activity_type` | enum | нет | `recycler` только для роли `buyer`, иначе 422 |
| `contacts` | ContactInfo | нет | заменяет целиком; не переданные внутри поля становятся null |

```json
{ "city": "Ош", "contacts": { "contact_name": "Айгуль", "contact_phone": "+996000000000", "contact_email": null } }
```

Ответ 200: `OrganizationOut`. Версии нет, последняя запись побеждает (раздел 4).

### 17.5 GET /materials и POST /materials

**GET** (enterprise: `Page<MaterialOut>`, buyer: `Page<MaterialPublicOut>`). Коды: 200, 401, 403, 422. Query - раздел 8.1; `page_size` > 100 - 422.

```json
{ "items": [ { "id": "7c0e3f2a-1d4b-4c8e-9a10-2b3c4d5e6f70", "name": "Хлопковые обрезки", "status": "draft", "version": 1 } ],
  "page": 1, "page_size": 20, "total": 1 }
```

(в `items` полный `MaterialOut`, пример сокращён).

**POST** (enterprise). Коды: 201, 401, 403 (buyer), 422.

| Поле запроса `MaterialCreateIn` | Тип | Обяз. | Правила |
| --- | --- | --- | --- |
| `name` | string | да | 1..200 |
| `material_type` | enum | нет, null | |
| `composition` | string | нет, null | 1..200; неизвестный состав - null/опустить, выдумывать нельзя |
| `scrap_size` | string | нет, null | 1..100, свободный текст (A17-7) |
| `condition` | enum | нет, null | |
| `price_per_kg` | money | нет, null | null = цена не задана, не ноль |
| `city` | string | нет, null | 1..100 |
| `total_kg` | mass | нет | по умолчанию `"0.000"` |

```json
{ "name": "Хлопковые обрезки", "material_type": "cotton", "composition": null, "scrap_size": "20x30 см",
  "condition": "good", "price_per_kg": "45.00", "city": "Бишкек", "total_kg": "120.500" }
```

Ответ 201 `MaterialOut`:

```json
{
  "id": "7c0e3f2a-1d4b-4c8e-9a10-2b3c4d5e6f70",
  "organization_id": "b2a8f3d4-6c1e-4f0a-8d77-4c5f7a0e9b22",
  "name": "Хлопковые обрезки", "material_type": "cotton", "composition": null, "scrap_size": "20x30 см",
  "condition": "good", "price_per_kg": "45.00", "city": "Бишкек", "status": "draft",
  "balance": { "total_kg": "120.500", "available_kg": "120.500", "held_kg": "0.000", "transferred_kg": "0.000", "internally_used_kg": "0.000" },
  "version": 1, "confirmed_at": null, "confirmed_by": null, "is_confirmation_current": false,
  "images": [], "created_at": "2026-11-07T10:20:00Z", "updated_at": "2026-11-07T10:20:00Z"
}
```

`status`, `balance`, `version`, `images`, `confirmed_*` только читаются.

### 17.6 GET и PATCH /materials/{id}

**GET.** enterprise-владелец - `MaterialOut`; buyer - `MaterialPublicOut` (только опубликованные: `available`, `partially_allocated`, A17-8: `reserved`/`completed`/`archived` скрыты). Чужой или скрытый - 404 `NOT_FOUND`. Коды: 200, 401, 404.

`MaterialPublicOut` (замораживаем поля): `id`, `organization_id`, `organization_name`, `name`, `material_type`, `composition`, `scrap_size`, `condition`, `price_per_kg`, `city`, `available_kg`, `status`, `images` (без ссылок), `version`, `created_at`. Нет `total_kg`, `held_kg`, `confirmed_by`, контактов.

**PATCH** (enterprise-владелец). Коды: 200, 401, 403, 404, 409 `VERSION_CONFLICT` / `ACTIVE_OBLIGATIONS`, 422.

| Поле `MaterialPatchIn` | Тип | Обяз. | Правила |
| --- | --- | --- | --- |
| `version` | int | да | значение, прочитанное клиентом |
| `name`, `material_type`, `composition`, `scrap_size`, `condition`, `price_per_kg`, `city`, `total_kg` | как в 17.5 | нет | минимум одно; null очищает необязательные; `status`/`balance` передавать нельзя (422) |

```json
{ "version": 3, "condition": "worn", "total_kg": "118.000" }
```

Ответ 200 `MaterialOut` с новой `version`. Изменение входных характеристик сбрасывает подтверждение (`is_confirmation_current=false`), опубликованная партия без обязательств возвращается в `draft` (раздел 4). 409 `VERSION_CONFLICT`: `details.current_version`.

### 17.7 POST /materials/{id}/images

**Способ загрузки: `multipart/form-data` через backend (не presigned URL в Storage).** Решение (A17-9), обоснование:
1. `CLAUDE.md` §11 требует проверку сигнатуры, декодирования, лимита байтов и пикселей до сохранения. При presigned upload файл попадает в bucket в обход этих проверок; пришлось бы вводить пост-проверку и очистку, то есть второй шаг, статусы «загружено, но не проверено» и фоновую уборку (в MVP фоновых сервисов нет).
2. Случайный object key, привязка к `material_id` и лимит 5 фото уже проверяются на сервере в одной точке.
3. Для мобильного клиента это один запрос; объём ограничен 10 MB, что допустимо при предварительном уменьшении на устройстве.
Цена: трафик идёт через backend. При росте нагрузки возможен переход на presigned отдельным решением (несовместимое изменение).

Роль: enterprise-владелец. Коды: 201, 401, 403, 404 (чужая партия), 409 `IMAGE_LIMIT_REACHED`, 422 `UNSUPPORTED_IMAGE`, 429.

Запрос: `Content-Type: multipart/form-data` (boundary ставит HTTP-клиент, вручную не задавать).

| Часть | Тип | Обяз. | Правила |
| --- | --- | --- | --- |
| `file` | binary | да | JPEG/PNG/WebP по сигнатуре и декодированию; <= 10 MB; <= 20 MP после декодирования. Имя и `Content-Type` клиента игнорируются |
| `sort_order` | int (текстовое поле формы) | нет | >= 0, по умолчанию в конец |

Рекомендация клиенту (не часть контракта): уменьшать длинную сторону до 2048 px и качество JPEG 85 до отправки, чтобы уложиться в 10 MB; EXIF-ориентацию применять на устройстве.

Ответ 201 `ImageUploadOut`:

```json
{ "image": { "id": "0f9e8d7c-6b5a-4c3d-8e2f-1a0b9c8d7e6f", "material_id": "7c0e3f2a-1d4b-4c8e-9a10-2b3c4d5e6f70",
             "mime_type": "image/jpeg", "size_bytes": 842113, "width_px": 2048, "height_px": 1536,
             "sort_order": 0, "created_at": "2026-11-07T10:22:00Z" },
  "material_version": 2 }
```

Ссылки на файл в ответе нет. Показ фото - `GET /materials/{id}/images/{image_id}/url` (8.5): `{ "url": "<signed>", "expires_at": "2026-11-07T10:27:00Z" }`; ссылку не кэшировать после `expires_at`, не логировать. `details` для 422 `UNSUPPORTED_IMAGE`: `{"reason": "signature|decode|bytes|pixels"}` (A17-10). 413/415 не используются; промежуточный прокси может вернуть 413 вне формата ошибки - клиент обрабатывает любой не-JSON ответ как неизвестную ошибку.

### 17.8 POST /materials/{id}/confirm

Роль: enterprise-владелец. Коды: 200, 401, 403, 404, 409 `VERSION_CONFLICT` / `PRECONDITION_FAILED`, 422.

| Поле `MaterialConfirmIn` | Тип | Обяз. | Правила |
| --- | --- | --- | --- |
| `version` | int | да | версия, которую человек видел на экране |
| `analysis_id` | uuid | нет, null | если задан: анализ этой партии, `succeeded`, `input_version == version`; иначе 409 `PRECONDITION_FAILED` |

```json
{ "version": 4, "analysis_id": "a1b2c3d4-e5f6-4a7b-8c9d-0e1f2a3b4c5d" }
```

Ответ 200 `MaterialOut` с `confirmed_at`, `confirmed_by`, `is_confirmation_current=true`. Подтверждаются значения полей партии, а не AI-предложения; AI ничего не подтверждает сам. Повтор для уже подтверждённой текущей версии - 200 без изменений. `PRECONDITION_FAILED.details.reason` (A17-10): `ANALYSIS_NOT_FOUND_FOR_MATERIAL`, `ANALYSIS_NOT_SUCCEEDED`, `ANALYSIS_STALE`. Неизвестный состав допустим.

### 17.9 POST /ai/analyze (202) и GET /ai/analyses/{id}

**POST.** Роль: enterprise-владелец. Коды: 202, 401, 403, 404, 409 `PRECONDITION_FAILED` (`details.reason = "NO_IMAGES"`), 422, 429.

Запрос `AnalyzeIn`: `material_id` (uuid, да).

Ответ 202, заголовок `Location: /ai/analyses/{analysis_id}`:

```json
{ "analysis_id": "a1b2c3d4-e5f6-4a7b-8c9d-0e1f2a3b4c5d", "status": "pending", "input_version": 4 }
```

Job сохраняется в БД до запуска (D-07). Недоступность AI не ломает партию. Повтор при активной (`pending`/`running`) задаче для той же партии и `input_version` - снова 202 с **существующим** `analysis_id` (A17-30, A-AI-6). В запросе нет `images` и `input_version`: фото берёт сервер по собственным object key, версию читает сервер.

**GET.** Роль: enterprise-владелец. Чужой - 404. Коды: 200, 401, 403, 404.

| Поле `AnalysisOut` | Тип | Обяз. | Примечание |
| --- | --- | --- | --- |
| `id` | uuid | да | |
| `material_id` | uuid | да | |
| `status` | `pending`/`running`/`succeeded`/`failed`/`interrupted` | да | терминальные: `succeeded`, `failed`, `interrupted` |
| `input_version` | int | да | |
| `is_current` | bool | да | `input_version` равна текущей `version` партии; при false результат подтвердить нельзя |
| `mode` | `live`/`mock`/`fallback` или null | да (ключ есть всегда) | **добавляется этой заморозкой, A17-11**; null пока не `succeeded`. Подробно в 17.13 |
| `requires_confirmation` | `true` | да | **добавлено (A17-30)**: всегда `true`, для любого статуса |
| `schema_version` | string или null | да | `"1.0"` (было `"1"`) |
| `provider`, `model` | string или null | да | для mock `provider = "mock"` |
| `result` | `VisionModelOutput` или null | да | только при `succeeded` после валидации; форма ниже |
| `error_code` | string или null | да | только при `failed`/`interrupted`; 9 значений: `PROVIDER_TIMEOUT`, `PROVIDER_UNAVAILABLE`, `INVALID_PROVIDER_RESPONSE`, `INTERRUPTED`, `PROVIDER_RATE_LIMITED`, `PROVIDER_AUTH_ERROR`, `PROVIDER_REFUSED`, `IMAGE_UNAVAILABLE`, `INTERNAL_ERROR` (A17-12 заменено, A17-30); без текста провайдера |
| `confirmed_at`, `confirmed_by` | datetime / uuid или null | да | |
| `created_at`, `updated_at` | datetime | да | |

`result` = `VisionModelOutput` (`docs/ai-schema.md` 2.1-2.3, 11.2). Внутри `result` **нет** `material_id`, `requires_confirmation`, `schema_version` (они на верхнем уровне `AnalysisOut`):
- `visual_features.color`: `{ primary, secondary[], description, confidence }`; `visual_features.pattern`: `{ value, description, confidence }`; `visual_features.apparent_texture`: `{ value, description, confidence }`. `confidence`: `high`/`medium`/`low`/`unknown`. Неизвестное: `value = null`, `confidence = "unknown"`.
- `reuse_options[]` (0..5): `reuse_type` (ReuseType = ReuseUse, раздел 2), `suitability` (`high`/`medium`/`low`/`unknown`), `reason` (10..300 символов).
- `notes`: string (до 500) или null, только визуальные замечания.

Клиент показывает всё как «предложение AI», не как факт; состава и прочности в нём нет.

Статусы на проводе не меняются: `pending`/`running`/`succeeded`/`failed`/`interrupted`; клиент отображает их как pending/processing/completed/failed (`interrupted` и неизвестное значение - failed; ai-schema 11.3). Устаревший анализ при подтверждении: 409 `PRECONDITION_FAILED`, `details.reason = "ANALYSIS_STALE"` (A-AI-1). `mode = "fallback"` (готовая фикстура) возможен только при `DEMO_MODE=true`; вне demo режима fallback не включается (A17-31).

```json
{
  "id": "a1b2c3d4-e5f6-4a7b-8c9d-0e1f2a3b4c5d", "material_id": "7c0e3f2a-1d4b-4c8e-9a10-2b3c4d5e6f70",
  "status": "succeeded", "input_version": 4, "is_current": true, "mode": "live",
  "requires_confirmation": true, "schema_version": "1.0", "provider": "configured-provider", "model": "configured-model",
  "result": {
    "visual_features": {
      "color": { "primary": "blue", "secondary": [], "description": "светло-синий", "confidence": "medium" },
      "pattern": { "value": "solid", "description": null, "confidence": "high" },
      "apparent_texture": { "value": null, "description": null, "confidence": "unknown" } },
    "reuse_options": [ { "reuse_type": "patchwork_crafts", "suitability": "high", "reason": "Однотонные крупные обрезки." } ],
    "notes": null },
  "error_code": null, "confirmed_at": null, "confirmed_by": null,
  "created_at": "2026-11-07T10:30:00Z", "updated_at": "2026-11-07T10:30:12Z"
}
```

Пример не-успеха: `"status": "failed", "mode": null, "result": null, "requires_confirmation": true, "error_code": "PROVIDER_TIMEOUT"`.

### 17.10 POST /ai/match

Роль: enterprise-владелец партии. Детерминированно, без LLM, та же функция совместимости, что у оптимизатора. Коды: 200, 401, 403, 404, 409 `PRECONDITION_FAILED` (`details.reason`: `NOT_CONFIRMED` или `CONFIRMATION_STALE`), 422, 429.

| Поле `MatchIn` | Тип | Обяз. | Правила |
| --- | --- | --- | --- |
| `material_id` | uuid | да | |
| `limit` | int | нет | 1..50, по умолчанию 20 |

```json
{ "material_id": "7c0e3f2a-1d4b-4c8e-9a10-2b3c4d5e6f70", "limit": 10 }
```

Ответ 200 `MatchOut` (предварительно до CON-03):

```json
{
  "material_id": "7c0e3f2a-1d4b-4c8e-9a10-2b3c4d5e6f70", "material_version": 4, "rules_version": "1",
  "matches": [ { "requirement_id": "c3d4e5f6-0a1b-4c2d-9e3f-4a5b6c7d8e9f", "organization_name": "Демо Мастерская",
                 "score": 85, "components": { "city": 30, "use": 30, "coverage": 25 },
                 "reasons": ["Тот же город", "Применение совпадает", "Покрывает 62% остатка спроса"],
                 "possible_kg": "75.000", "city": "Бишкек" } ],
  "excluded": [ { "requirement_id": "d4e5f6a7-1b2c-4d3e-8f4a-5b6c7d8e9f0a",
                  "reason_codes": ["MIN_KG_EXCEEDS_AVAILABLE"], "reasons": ["Минимальный объём больше доступного остатка"] } ]
}
```

| Поле | Тип | Обяз. |
| --- | --- | --- |
| `matches[].score` | int 0..100 | да |
| `matches[].components` | `{city, use, coverage}` int | да |
| `matches[].possible_kg` | mass | да |
| `matches[].city` | string или null | да |
| `excluded[].reason_codes`, `reasons` | string[] | да |

Бюджет и контакты покупателя в ответе нет никогда. Сортировка: `score` убыв., затем `requirement_id` возр.

### 17.11 POST /optimization/run и GET /optimization/runs/{id}

**POST.** Роль: enterprise. План - рекомендация: остатки, статусы, спрос не меняются. Синхронно, лимит времени `OPTIMIZATION_TIMEOUT_SECONDS`; клиент ставит таймаут запроса не меньше 30 с (A17-13). Коды: 201, 401, 403, 404 (любая партия не своя), 409 `PRECONDITION_FAILED` (`details.reason = "NOT_CONFIRMED"`, `details.material_ids` - какие), 422, 429.

| Поле `OptimizationRunIn` | Тип | Обяз. | Правила |
| --- | --- | --- | --- |
| `material_ids` | uuid[] | да | 1..20, без дублей |
| `assumptions` | object | нет, null | входные допущения; отсутствующее не заменяется нулём |
| `assumptions.internal_use` | `{value_per_kg: money, cost_per_kg: money, capacity_kg: mass}` | нет, null | прогноз экономии, не выручка |
| `assumptions.recycling` | то же | нет, null | |
| `assumptions.delivery_cost_per_kg` | money | нет, null | одинаково в baseline и оптимизации |

```json
{ "material_ids": ["7c0e3f2a-1d4b-4c8e-9a10-2b3c4d5e6f70"],
  "assumptions": { "internal_use": { "value_per_kg": "30.00", "cost_per_kg": "2.00", "capacity_kg": "40.000" },
                   "recycling": { "value_per_kg": "10.00", "cost_per_kg": "1.00", "capacity_kg": "200.000" },
                   "delivery_cost_per_kg": "3.00" } }
```

Ответ 201 `OptimizationRunOut`:

```json
{
  "id": "e5f6a7b8-2c3d-4e4f-9a5b-6c7d8e9f0a1b", "status": "optimal", "method": "scipy_milp",
  "algorithm_version": "1", "rules_version": "1", "label": "expected",
  "objective_kgs": "3120.00",
  "baseline": { "method": "greedy_by_unit_margin", "value_kgs": "2850.00" },
  "delta_vs_baseline_kgs": "270.00",
  "allocations": [ { "material_id": "7c0e3f2a-1d4b-4c8e-9a10-2b3c4d5e6f70", "direction": "sale",
                     "requirement_id": "c3d4e5f6-0a1b-4c2d-9e3f-4a5b6c7d8e9f", "quantity_kg": "75.000",
                     "unit_value_kgs": "45.00", "unit_cost_kgs": "3.00", "net_value_kgs": "3150.00",
                     "explanation": "Покупатель в том же городе, цена не выше бюджета." } ],
  "remainder": [ { "material_id": "7c0e3f2a-1d4b-4c8e-9a10-2b3c4d5e6f70", "remainder_kg": "5.500" } ],
  "input_versions": [ { "material_id": "7c0e3f2a-1d4b-4c8e-9a10-2b3c4d5e6f70", "version": 4 } ],
  "assumptions": { "delivery_cost_per_kg": { "value": "3.00", "origin": "user_input" } },
  "solve_time_ms": 41, "is_stale": false, "created_at": "2026-11-07T10:40:00Z"
}
```

(числа примера иллюстративны, не расчёт.) Поля: все перечисленные в разделе 11.1 обязательны в ответе; `status` из `SolverStatus`; `feasible` и `heuristic` клиент подписывает как «не доказанный оптимум». `label` всегда `"expected"`: клиент показывает «ожидается», не «продано». Знак минус допустим только в `delta_vs_baseline_kgs` и `allocations[].net_value_kgs` (формат `-12.00`). `remainder` показывается явно. Для `infeasible`/`timeout`/`error` массивы `allocations` могут быть пусты, `objective_kgs = "0.00"` (A17-21).

**GET /optimization/runs/{id}.** Роль: enterprise-владелец, чужой - 404. Коды: 200, 401, 403, 404. Ответ - тот же `OptimizationRunOut`, `is_stale` вычисляется при чтении: true, если версия любой партии из `input_versions` изменилась; клиент предлагает «Пересчитать» (новый POST), старый план остаётся для просмотра.

### 17.12 POST /reservations (Idempotency-Key)

Роль: `buyer`. Создаёт заявку `pending`, запас не удерживается (удержание - при `confirm` продавцом). Коды: 201, 401, 403 (enterprise), 404 (партия не опубликована, `requirement_id` чужой), 409 `INSUFFICIENT_STOCK` / `IDEMPOTENCY_KEY_REUSED`, 422.

Заголовки: `Authorization`, `Idempotency-Key` (обязателен; 8..128 `[A-Za-z0-9_-]`, UUIDv4 с клиента, генерируется один раз на намерение и сохраняется до получения ответа; повтор после обрыва сети - тот же ключ и то же тело). Без ключа - 422. Ответ повтора: исходный статус и тело, заголовок `Idempotent-Replay: true`.

| Поле `ReservationCreateIn` | Тип | Обяз. | Правила |
| --- | --- | --- | --- |
| `material_id` | uuid | да | опубликованная партия |
| `requirement_id` | uuid | нет, null | своя активная потребность |
| `quantity_kg` | mass | да | > 0; <= текущего `available_kg` (предварительно, без блокировки); при `requirement_id` >= его `min_kg` |
| `agreed_price_per_kg` | money | нет, null | null: берётся `price_per_kg` партии; у партии цены нет - 422 (нулём не подставляется) |

```json
{ "material_id": "7c0e3f2a-1d4b-4c8e-9a10-2b3c4d5e6f70", "requirement_id": "c3d4e5f6-0a1b-4c2d-9e3f-4a5b6c7d8e9f",
  "quantity_kg": "50.000", "agreed_price_per_kg": null }
```

Ответ 201 `ReservationOut`:

```json
{
  "id": "f6a7b8c9-3d4e-4f50-8a6b-7c8d9e0f1a2b", "material_id": "7c0e3f2a-1d4b-4c8e-9a10-2b3c4d5e6f70",
  "material_name": "Хлопковые обрезки", "seller_organization_id": "b2a8f3d4-6c1e-4f0a-8d77-4c5f7a0e9b22",
  "buyer_organization_id": "9e8d7c6b-5a4f-4e3d-8c2b-1a0f9e8d7c6b", "requirement_id": "c3d4e5f6-0a1b-4c2d-9e3f-4a5b6c7d8e9f",
  "quantity_kg": "50.000", "agreed_price_per_kg": "45.00", "status": "pending",
  "cancel_reason": null, "cancelled_by_role": null, "transaction": null, "counterparty_contacts": null,
  "created_at": "2026-11-07T11:00:00Z", "updated_at": "2026-11-07T11:00:00Z"
}
```

Контакты контрагента `null` до статуса `confirmed` (раздел 16, п. 11).

### 17.13 Ответы на вопросы Flutter-клиента

**Q1. Форма ошибки 409: есть ли `available_kg` и `request_id` в теле?** Да, оба. Конверт един для всех кодов (раздел 1.2), `request_id` есть всегда и в теле (`error.request_id`), и в заголовке `X-Request-ID`. Для 409 `error.details` заморожен так:

| `code` | `details` | Статус |
| --- | --- | --- |
| `INSUFFICIENT_STOCK` | `{"available_kg": "10.000", "requested_kg": "25.000"}` | заморожено (раздел 1.2) |
| `DEMAND_EXCEEDED` | `{"remaining_demand_kg": "20.000", "requested_kg": "25.000"}` | допущение A17-15 |
| `VERSION_CONFLICT` | `{"current_version": 5}` | заморожено (раздел 4) |
| `INVALID_TRANSITION` | `{"current_status": "confirmed"}` | допущение A17-15 |
| `PRECONDITION_FAILED` | `{"reason": "<код>"}` плюс по случаю `material_ids` | допущение A17-15 |
| `IDEMPOTENCY_KEY_REUSED`, `ACTIVE_OBLIGATIONS`, `IMAGE_LIMIT_REACHED`, `EMAIL_ALREADY_REGISTERED` | `null` | |

```json
{ "error": { "code": "INSUFFICIENT_STOCK", "message": "Недостаточно свободной массы для резерва.",
             "details": { "available_kg": "10.000", "requested_kg": "25.000" },
             "request_id": "9f0c2c9e-6d2b-4b5a-8f3e-2f1d5e7a1c11" } }
```

Клиент: показывает `message` как есть (русский, безопасный), при `INSUFFICIENT_STOCK` подставляет `available_kg` в подсказку и перезапрашивает карточку; `request_id` показывает мелким шрифтом для обращения в поддержку. Ключ ошибки всегда `error` (конверт), код и логика - по `error.code`, не по тексту `message`. Значение `available_kg` в 409 - снимок на момент проверки, не гарантия на следующий запрос. Все ошибки, включая 401/404/422/429/500, в том же формате; прокси-ошибки вне формата - см. 17.7.

**Q2. Поле `mode` у AI-результата.** В черновике CON-01 поля не было (был только `provider`, у mock `"mock"`). Замораживается как `AnalysisOut.mode`, enum `live` | `mock` | `fallback`, null пока анализ не `succeeded` (A17-11):
- `live` - ответ реального vision-провайдера из конфигурации;
- `mock` - тестовый/demo mock-провайдер, явно не живой AI;
- `fallback` - заранее подготовленный fixture при недоступности сети/провайдера (`CLAUDE.md` §16), честно помеченный.
Клиент обязан показывать плашку для `mock` («демо-данные AI») и `fallback` («резервный режим, не результат анализа вашего фото»). Для `live` плашка не нужна, но подпись «предложение AI, требует подтверждения» остаётся всегда. `mode` определяет сервер по конфигурации, клиент его не передаёт. Окончательное определение `fallback` и схема - за CON-02 (ai-engineer); до этого поле «предварительно».

**Q3. Видимость `budget_per_kg` для enterprise.** Скрыто. В `BuyerRequirementOut` для роли `enterprise` ключ `budget_per_kg` отсутствует (не `null`: `null` означает «бюджет не задан» у самого покупателя), контакты организации тоже. Покупатель видит `budget_per_kg` только своих потребностей. Бюджет используется только на сервере внутри matching/optimizer и не раскрывается ни в `MatchOut`, ни в `OptimizationRunOut`, ни в `ReservationOut`. Клиент не должен отрисовывать поле бюджета на enterprise-экранах и должен допускать его отсутствие в DTO (nullable/optional). В мобильном P0 enterprise `GET /buyer-requirements` не обязателен (потребности видны через matching).

### 17.14 Соглашение по связке «план -> резерв» (P0)

План и matching - рекомендации; резерв создаёт только `buyer` через `POST /reservations`, продавец подтверждает `PATCH /reservations/{id}` `{"action":"confirm"}`. Enterprise-клиент не создаёт резерв от имени покупателя и не «применяет план» одной кнопкой (допущение A17-16; см. вопрос оркестратору). Перед каждым реальным резервом сервер заново проверяет остаток и спрос.

### 17.15 Новые допущения этого раздела

- A17-1: `confirm` не увеличивает `version`; следующий `publish` использует ту же версию.
- A17-2: опрос анализа с интервалом 2 с, потолок 90 с на стороне клиента.
- A17-3: пароль 10..128 символов (то же, что раздел 16, п. 12).
- A17-4: формат телефона и email контактов не валидируется сверх типа и длины.
- A17-5: 409 `EMAIL_ALREADY_REGISTERED` допускает перебор email.
- A17-6: неактивный пользователь получает `INVALID_CREDENTIALS`, не 403.
- A17-7: `scrap_size` - свободный текст.
- A17-8: buyer не видит `reserved`/`completed`/`archived` (раздел 16, п. 6).
- A17-9: загрузка фото - multipart через backend.
- A17-10: `details.reason` для `UNSUPPORTED_IMAGE` и `PRECONDITION_FAILED`, набор значений выше.
- A17-11: поле `AnalysisOut.mode` (`live`/`mock`/`fallback`).
- A17-12: набор `error_code` анализа: `PROVIDER_TIMEOUT`, `PROVIDER_UNAVAILABLE`, `INVALID_PROVIDER_RESPONSE`, `INTERRUPTED`. **Заменено A17-30** (9 значений).
- A17-30: выравнивание с `docs/ai-schema.md` раздел 11: `result` = `VisionModelOutput`, `requires_confirmation` на верхнем уровне `AnalysisOut`, `use`->`reuse_type`, `texture`->`apparent_texture`, `schema_version "1.0"`, 9 `error_code`, повторный POST при активной задаче - 202 с прежним `analysis_id`.
- A17-31: фикстура `mode = fallback` только при `DEMO_MODE=true`.
- A17-13: таймаут клиента на `/optimization/run` >= 30 с.
- A17-14: при `infeasible`/`timeout`/`error` план пуст, `objective_kgs = "0.00"`.
- A17-15: состав `details` для `DEMAND_EXCEEDED`, `INVALID_TRANSITION`, `PRECONDITION_FAILED`.
- A17-16: резерв создаёт только покупатель; кнопки «применить план» нет.

### 17.16 Что backend должен сделать ДО интеграции мобильного клиента

Состояние на 2026-11-07: ничего не реализовано. Абсолютный `START` хакатона не записан (D-09, BLK-01 открыт), поэтому сроки ниже - предложение относительно текущей даты, оркестратор подтверждает или сдвигает. Порядок строго последовательный (одна миграционная линия, `DEPENDENCIES.md` §6).

| Приоритет | Задача | Предлагаемый срок | Что должно быть готово для мобильного клиента |
| --- | --- | --- | --- |
| P0-1 | **BE-01** skeleton: FastAPI app, `core/config` (обязательный `JWT_SECRET`, `DATABASE_URL`, без default-секретов), единый конверт ошибок с `request_id` и заголовком `X-Request-ID`, `GET /health`, SQLAlchemy base/session, Alembic baseline (`python -m alembic upgrade head` на пустой БД), ruff, pytest с отдельной PostgreSQL, OpenAPI | 2026-11-08 | Клиент может ходить на `/health` и получать ошибку в конверте; опубликован `/openapi.json` для сверки DTO |
| P0-2 | **BE-02** auth: модели users/organizations, `register`, `login`, JWT (HS256 allowlist, `exp`), Argon2id, `GET/PATCH /organizations/me`, 401/403/404, rate limit login/register, тесты ролей | 2026-11-09 | Экраны входа, регистрации и профиля интегрируются на реальном API (17.2-17.4) |
| P0-3 | BE-03 materials (CRUD, version, confirm, publish): нужен для P0-шага «партия -> подтверждение», блокирует AI-02 и FE-02 | 2026-11-10 | Нужны для 17.5, 17.6, 17.8 |
| P0-4 | BE-04 images (multipart, проверка сигнатуры и декодирования, Storage-адаптер) | 2026-11-11 | 17.7 |
| далее | BE-05 requirements, затем AI-02/AI-04 и OPT-02 (не backend-engineer), BE-06 reservations | по плану Wave 2-3 | 17.9-17.12 |

Блокеры, не зависящие от backend: решение по `mode` (CON-02), форма `assumptions` (CON-03), доступ к Supabase Storage (для BE-04), значение START (BLK-01).
До BE-02 мобильный клиент работает только на моках; до BE-03/BE-04 не интегрируется ни одно изменение каталога.

## 18. Frozen for mobile Phase 2 - materials

Статус: предварительная заморозка контракта партий для мобильного клиента (экраны S04 «Создание/редактирование партии» и S05 «Карточка партии»). Дата записи: 2026-11-07. Владелец: backend-engineer. Требует утверждения оркестратора.

**Состояние реализации: НИЧЕГО НЕ РЕАЛИЗОВАНО.** BE-01 и BE-03 в статусе todo: нет маршрутов, моделей, миграций. Всё ниже - контракт, а не описание работающего кода. Клиент работает с моками; интеграция - после BE-03/BE-04.

Правила:
- Разделы 1-17 не переписываются; здесь они уточняются и дополняются. Если что-то в 18 расходится с 1-17, приоритет у 18, и это расхождение явно названо (18.1 п. 2, 18.10).
- Допущения, которых нет в `CLAUDE.md`, помечены «допущение» и пронумерованы A18-n (список в 18.12).
- Формулировки «заморожено ранее» означают, что поведение уже зафиксировано в разделах 1-17 и не меняется.

### 18.1 Ошибки валидации 422: формат `details.errors[]` (ответ на вопрос клиента 1)

Конверт - раздел 1.2. Для `422 VALIDATION_ERROR` и `422 PUBLISH_REQUIREMENTS_NOT_MET` (не для `UNSUPPORTED_IMAGE`) `error.details.errors` - массив:

```json
{ "error": { "code": "VALIDATION_ERROR", "message": "Проверьте заполненные поля.",
  "details": { "errors": [
    { "field": "organization.contacts.contact_phone", "code": "too_long", "message": "Не более 200 символов." },
    { "field": "uses.1", "code": "invalid_value", "message": "Недопустимое значение." },
    { "field": "total_kg", "code": "too_many_decimals", "message": "Не более 3 знаков после точки." } ] },
  "request_id": "9f0c2c9e-6d2b-4b5a-8f3e-2f1d5e7a1c11" } }
```

1. **Формат `field` (окончательный, A18-1):** путь от корня JSON-тела запроса, сегменты через точку, имена - ровно как в JSON (snake_case). Индекс элемента массива - отдельный числовой сегмент с нуля: `uses.1`, `items.0.quantity_kg`. Вложенный объект: `organization.name`, `organization.contacts.contact_phone`. Префиксов `body`, `$`, `data` нет. Для query-параметров - имя параметра (`page_size`, `material_type.0`); для multipart - имя части (`file`, `sort_order`); для заголовка - точное имя заголовка (`Idempotency-Key`). Ошибка уровня всего объекта (например, «нужно хотя бы одно поле», `min_kg > max_kg` без привязки) - `field: ""` (пустая строка, A18-2); ошибки пары полей привязываются к более «правому» полю (`max_kg`). Лишнее поле: `field` = путь этого поля, `code` = `extra_forbidden`.
2. `errors[].code` - стабильный машинный код (A18-3): `required`, `null_not_allowed`, `invalid_type`, `invalid_value` (не из enum или неверный формат), `too_short`, `too_long`, `out_of_range`, `invalid_decimal`, `too_many_decimals`, `extra_forbidden`, `no_changes` (PATCH без изменяемых полей), `mass_must_be_positive`. Клиент выбирает поведение по `code`, показывает `message` (русский, безопасный). Неизвестный `code` клиент трактует как общую ошибку поля.
3. Порядок элементов - порядок полей в DTO, затем по индексу; сервер возвращает все найденные ошибки сразу, не только первую (A18-4). Значение, которое прислал клиент, в `message` и `details` не повторяется.
4. Клиент сопоставляет `field` с полем формы по точному совпадению; если поле на экране не найдено - показывает `message` общим баннером.

Расхождение с разделом 1.2: пример `"field": "min_kg"` остаётся верным (корневое поле); формат для вложенных полей определён здесь.

### 18.2 Коды ошибок Фазы 2 (все маршруты материалов и входа)

Единый конверт и список 1.2 заморожены. Ниже - применимость по маршрутам Фазы 2 и два уточнения.

| Маршрут | Возможные ответы |
| --- | --- |
| `GET /materials` | 200, 401 `UNAUTHENTICATED`, 403 `FORBIDDEN` (admin), 422 `VALIDATION_ERROR`, 429 не применяется |
| `POST /materials` | 201, 401, 403 (buyer), 422 |
| `GET /materials/{id}` | 200, 401, 404 `NOT_FOUND` (чужое, скрытое, несуществующее, неверный формат UUID - тоже 404, не 422, A18-5) |
| `PATCH /materials/{id}` | 200, 401, 403, 404, 409 `VERSION_CONFLICT` / `ACTIVE_OBLIGATIONS`, 422 |
| `POST /materials/{id}/images` | 201, 401, 403, 404, 409 `IMAGE_LIMIT_REACHED`, 422 `UNSUPPORTED_IMAGE`, 429 `RATE_LIMITED` |
| `DELETE /materials/{id}/images/{image_id}` | 200, 401, 403, 404, 409 `ACTIVE_OBLIGATIONS` |
| `GET /materials/{id}/images/{image_id}/url` | 200, 401, 404 |
| `POST /auth/login` | 200, 401 `INVALID_CREDENTIALS`, 403 `ACCOUNT_DISABLED`, 422, 429 `RATE_LIMITED` |

Новый код в таблицу 1.2: `403 ACCOUNT_DISABLED` (18.9).
Уточнение: 403 `FORBIDDEN` для buyer на enterprise-маршрутах партий; для enterprise на чужую партию - 404, не 403 (раздел 1.1, заморожено).
Уточнение: тело, не являющееся JSON-объектом, и неверный `Content-Type` - 422 `VALIDATION_ERROR` с `field: ""`. Тело больше лимита сервера для JSON-маршрутов (64 KB, A18-6) - 422 с `field: ""`, `code: "too_long"`.

### 18.3 GET /materials

Роли: `enterprise` - только свои партии (по `organization_id` из токена, не из параметров), `Page<MaterialOut>`; `buyer` - только опубликованные чужие, `Page<MaterialPublicOut>`. Остальные фильтры - раздел 8.1 (заморожено). Коды: 200, 401, 403, 422.

| Параметр | Тип | Значение по умолчанию | Правила |
| --- | --- | --- | --- |
| `page` | int | 1 | >= 1; иначе 422 `field: "page"`, `out_of_range`. Страница за пределами диапазона - 200 с пустым `items` |
| `page_size` | int | 20 | 1..100; больше 100 - 422 (не обрезается молча), `field: "page_size"`, `out_of_range` |
| `status` | MaterialStatus | не задан | Только enterprise. Неизвестное значение - 422 `invalid_value`. У buyer параметр игнорируется (заморожено 8.1), даже невалидный - 422 только по формату enum |
| `q` | string | не задан | 1..100 после trim; пустая строка - 422 `too_short`. Поиск подстроки по `name`, без учёта регистра; спецсимволы `%` и `_` экранируются сервером (A18-7). Без полнотекстового поиска и опечаток |

Ответ 200:

```json
{ "items": [ { "id": "7c0e3f2a-1d4b-4c8e-9a10-2b3c4d5e6f70", "name": "Хлопковые обрезки", "status": "draft", "version": 1 } ],
  "page": 1, "page_size": 20, "total": 1 }
```

(в `items` полный DTO; пример сокращён). `total` - число записей по фильтрам до пагинации. Порядок - `sort` (по умолчанию `created_at_desc`, затем `id`). Архивные партии: по умолчанию `status` не задан и enterprise получает все статусы, кроме `archived`; `status=archived` показывает архив (A18-8; уточняет «любой статус» в разделе 5). У buyer архивных, черновых, `reserved` и `completed` партий нет (A17-8).

### 18.4 POST /materials

Роль: `enterprise`. Коды: 201, 401, 403, 422. `Idempotency-Key` не используется: повтор создаёт второй черновик (A18-9; клиент блокирует повторную отправку, раздел 14 CLAUDE.md).

`MaterialCreateIn` (лишние поля - 422 `extra_forbidden`):

| Поле | Тип JSON | Обяз. | Правила |
| --- | --- | --- | --- |
| `name` | string | да | trim, 1..200 |
| `material_type` | string enum | нет, null | `cotton`, `wool`, `linen`, `silk`, `synthetic`, `knit`, `denim`, `mixed`, `other` |
| `composition` | string | нет, null | trim, 1..200; «неизвестно» - опустить или null; строка «Неизвестно» как значение не нужна и не заменяется |
| `scrap_size` | string | нет, null | trim, 1..100, свободный текст |
| `condition` | string enum | нет, null | `unused`, `good`, `worn`, `damaged` |
| `price_per_kg` | string decimal | нет, null | >= 0, до 2 знаков, до 12 цифр целой части; KGS; null = цена не задана, не ноль |
| `city` | string | нет, null | trim, 1..100. Справочника городов нет: свободная строка (A18-10); сопоставление в фильтрах - без учёта регистра, точное |
| `total_kg` | string decimal | нет | по умолчанию `"0.000"`; >= 0, до 3 знаков, до 9 цифр целой части; кг. Ноль допустим только у черновика |

Число JSON вместо строки для `total_kg`/`price_per_kg` - 422 `invalid_type`; лишние знаки - 422 `too_many_decimals` (не округляется); отрицательное - `out_of_range`; не число - `invalid_decimal`. Пустая строка вместо null для необязательных - 422 `too_short` (клиент передаёт null или опускает поле).

Сервер сам задаёт: `id`, `organization_id` (из токена), `status = "draft"`, `version = 1`, `balance` (`available_kg = total_kg`, остальные `"0.000"`), `confirmed_at/by = null`, `is_confirmation_current = false`, `images = []`, `created_at`, `updated_at`. Ответ 201 - `MaterialOut` (пример в 17.5) и заголовок `Location: /materials/{id}` (A18-11).

### 18.5 GET /materials/{id}

Коды: 200, 401, 404. Enterprise-владелец - `MaterialOut` (3.6): `id`, `organization_id`, `name`, `material_type`, `composition`, `scrap_size`, `condition`, `price_per_kg`, `city`, `status`, `balance` {`total_kg`, `available_kg`, `held_kg`, `transferred_kg`, `internally_used_kg`}, `version`, `confirmed_at`, `confirmed_by`, `is_confirmation_current`, `images[]`, `created_at`, `updated_at`. Buyer - `MaterialPublicOut` (17.6) только для опубликованной партии, иначе 404.

`images[]` - `MaterialImageOut`: `id`, `material_id`, `mime_type`, `size_bytes`, `width_px`, `height_px`, `sort_order`, `created_at`. Нет object key, нет URL, нет подписанной ссылки. Порядок - по `sort_order`, затем `created_at`. Показ фото - `GET /materials/{id}/images/{image_id}/url` (8.5): ссылка короткоживущая (минуты, значение в конфигурации), `expires_at` в ответе; не кэшировать после `expires_at`, не логировать. Запрос на ссылку чужой партии или `image_id` другой партии - 404.

Поля `held_kg`, `transferred_kg`, `internally_used_kg`, `confirmed_by` у buyer отсутствуют.

### 18.6 PATCH /materials/{id}

Роль: enterprise-владелец. Коды: 200, 401, 403, 404, 409 `VERSION_CONFLICT` / `ACTIVE_OBLIGATIONS`, 422.

**Версия передаётся полем `version` в теле (решение A18-12), заголовок `If-Match` не используется и игнорируется.** Обоснование:
1. Уже заморожено в разделе 4 и 17.6 и совпадает с `POST /materials/{id}/confirm` (тело с `version`); два механизма на одном ресурсе - источник ошибок клиента.
2. `version` - целое число в `MaterialOut`; ETag/If-Match потребовал бы второго представления версии, обработки слабых/сильных ETag и 412/428 вместо согласованных 409/422.
3. Мобильные HTTP-клиенты и прокси не требуют особой обработки тела; одна валидация Pydantic выдаёт `field: "version"` при отсутствии.
Отсутствие `version` - 422 `required`, `field: "version"`; не целое - `invalid_type`; `< 1` - `out_of_range`.

Разрешённые поля (все необязательные, но минимум одно, иначе 422 `no_changes`, `field: ""`): `name`, `material_type`, `composition`, `scrap_size`, `condition`, `price_per_kg`, `city`, `total_kg` - типы и правила как в 18.4. `null` очищает необязательные (`material_type`, `composition`, `scrap_size`, `condition`, `price_per_kg`, `city`); для `name` и `total_kg` null - 422 `null_not_allowed`. Нельзя: `status`, `balance`, `confirmed_*`, `images`, `id`, `organization_id` - 422 `extra_forbidden`. Значения, равные текущим, не считаются изменением, но `version` всё равно проверяется; если после сравнения изменений нет, ответ 200 без увеличения `version` (A18-13).

Порядок проверок: 404 (владение) -> 422 (форма) -> 409 `VERSION_CONFLICT` -> 409 `ACTIVE_OBLIGATIONS` -> применение. Сравнение и инкремент атомарные (условный UPDATE или `SELECT FOR UPDATE`).

409 `VERSION_CONFLICT`: `details: {"current_version": 5}`; изменения не применены. Клиент перезагружает карточку и показывает баннер «Обновить данные» (S04); введённые пользователем значения сохраняются на экране для копирования.

409 `ACTIVE_OBLIGATIONS` (раздел 4): запрет менять `material_type`, `condition`, `city`, `total_kg`, если `held_kg > 0` или `transferred_kg > 0`; снижение `total_kg` ниже `held_kg + transferred_kg + internally_used_kg` - тоже. `details` = `{"blocked_fields": ["condition", "total_kg"]}` (A18-14, список полей, которые клиент пытался менять и которые запрещены); при смешанном запросе (разрешённые и запрещённые поля) не применяется ничего. Разрешено при обязательствах: `name`, `price_per_kg`, `composition`, `scrap_size` (A18-15: последние два не входят в список запретов раздела 4 и не влияют на баланс). Клиент заранее делает эти поля read-only, если `held_kg > 0` или `transferred_kg > 0` (текст S04: «Нельзя изменить: есть активные заявки.»); сервер всё равно проверяет. Резерв `pending` обязательством не считается.

Побочные эффекты (заморожено в разделе 4, напоминание): увеличение `version` на 1, сброс подтверждения при изменении входных характеристик, возврат опубликованной партии без обязательств в `draft`, устаревание планов (`is_stale`) и анализов. Ответ 200 - `MaterialOut` с новой `version`.

### 18.7 POST /materials/{id}/images и DELETE фото

**Загрузка.** Решение зафиксировано в 17.7 (multipart через backend); здесь - полные лимиты и ошибки. Роль: enterprise-владелец. Коды: 201, 401, 403, 404, 409, 422, 429.

Запрос: `multipart/form-data`; часть `file` (binary, обязательна), часть `sort_order` (необязательно, int >= 0 в текстовом виде; по умолчанию - в конец; если занят - существующие со `sort_order >= значения` сдвигаются на 1, A18-16). Имя файла и `Content-Type` части игнорируются.

| Лимит | Значение | Ответ при нарушении |
| --- | --- | --- |
| Число фото на партию | 5 | 409 `IMAGE_LIMIT_REACHED` (заморожено ранее; не 422), `details: {"max_images": 5}` (A18-17) |
| Размер файла | 10 MB (10 485 760 байт) | 422 `UNSUPPORTED_IMAGE`, `details: {"reason": "bytes", "max_bytes": 10485760}` |
| Размер после декодирования | 20 MP (20 000 000 пикселей) | 422 `UNSUPPORTED_IMAGE`, `details: {"reason": "pixels", "max_pixels": 20000000}` |
| Формат | JPEG, PNG, WebP по сигнатуре (magic bytes), затем успешное декодирование | 422 `UNSUPPORTED_IMAGE`, `reason`: `signature` (не тот формат/сигнатура) или `decode` (файл повреждён) |
| Отсутствует часть `file` | - | 422 `VALIDATION_ERROR`, `field: "file"`, `code: "required"` |
| Неверный `sort_order` | - | 422 `VALIDATION_ERROR`, `field: "sort_order"` |

Для превышения байтов/пикселей отдельного кода ошибки нет: используется `UNSUPPORTED_IMAGE` с `details.reason` (так заморожено в 17.7 и в D-11; новый код был бы несовместимым изменением). Сервер читает тело с ограничением и прекращает чтение после 10 MB (+ запас на границы multipart), не загружая файл целиком. Порядок проверок: владение (404) -> лимит 5 (409) -> формат/размер/пиксели (422). EXIF-метаданные (GPS) сервер удаляет при пересохранении (A18-18).

Ответ 201 `ImageUploadOut`: `{ "image": MaterialImageOut, "material_version": int }`; `material_version` = новая версия партии (+1; сброс подтверждения, раздел 4). Пример - 17.7. `image.id` и `image.sort_order` присутствуют всегда. Object key и URL не возвращаются.

**Удаление фото (P1, контракт заморожен предварительно, A18-19).** `DELETE /materials/{id}/images/{image_id}`. Роль: enterprise-владелец. Тела и `version` нет. Ответ 200: `{ "material_version": 4, "images": [MaterialImageOut] }` (оставшиеся фото). Эффекты: файл удаляется из Storage; `version` +1; подтверждение сбрасывается; если фото больше нет и партия опубликована без обязательств - возврат в `draft`; при `held_kg > 0` или `transferred_kg > 0` - 409 `ACTIVE_OBLIGATIONS`. `image_id` другой партии или несуществующий - 404; повторный DELETE того же фото - 404. Если backend не успеет, клиент скрывает кнопку «удалить» (в S04 это «remove» плитки) и не вызывает маршрут; для Фазы 2 обязательна только загрузка.

Переупорядочивание фото в Фазу 2 не входит (в S04 «reorder optional»); порядок задаётся `sort_order` при загрузке.

### 18.8 Статусы партии: что вычисляет сервер, что видит клиент

`status` - только чтение. Клиент не отправляет его ни в POST, ни в PATCH (422 `extra_forbidden`) и не меняет напрямую; смена статуса - только побочный эффект операций: `publish`, `archive`, резерв, передача, внутреннее использование, PATCH характеристик. Сервер пересчитывает статус единым сервисом (CLAUDE.md §5), в одной транзакции с изменением остатков.

| `status` | Условие (сервер) | Подпись для клиента (S05) | Что видит buyer |
| --- | --- | --- | --- |
| `draft` | Не опубликована (или возвращена в черновик после изменения характеристик) | Черновик | Нет (404) |
| `available` | Опубликована, `available_kg = total_kg` | Доступна | Да |
| `partially_allocated` | Опубликована, часть массы удерживается/передана/использована, `available_kg > 0` | Частично распределена | Да (только `available_kg`) |
| `reserved` | `available_kg = 0`, есть активный резерв (`held_kg > 0`) | Зарезервирована | Нет (A17-8) |
| `completed` | Вся масса выбыла (`transferred_kg + internally_used_kg = total_kg`), `held_kg = 0` | Завершена | Нет |
| `archived` | Скрыта владельцем при отсутствии активных резервов | В архиве | Нет |

Клиент не вычисляет статус из остатков и не угадывает переходы; по неизвестному значению показывает нейтральную подпись. Доступность кнопок (S05) определяется `status` и `balance` из последнего ответа; окончательную проверку делает сервер (409 `INVALID_TRANSITION` / `PRECONDITION_FAILED`). Публикация требует: тип, положительная масса, состояние, город, хотя бы одно фото и актуальное подтверждение (`is_confirmation_current = true`), иначе 422 `PUBLISH_REQUIREMENTS_NOT_MET`, `details.missing` - список из `material_type`, `total_kg`, `condition`, `city`, `images`, `confirmation` (A18-20; чек-лист «Что осталось» на S05). Предложенный план и AI-анализ статус и массу не меняют.

### 18.9 Ответы на вопросы клиента 2 и 3 (вход)

**Q2. Отключённая учётная запись при входе (A18-21, заменяет A17-6).** `403 ACCOUNT_DISABLED`, `details: null`, сообщение «Учётная запись отключена. Обратитесь в поддержку.». Принято с условием: сервер сначала проверяет пароль; ответ 403 возвращается только если email найден **и пароль верен** и `active = false`. Неверный пароль у отключённой записи и неизвестный email дают прежний 401 `INVALID_CREDENTIALS`, поэтому по ответу нельзя узнать состояние чужой записи без пароля (перебор email не расширяется). Для времени ответа выполняется проверка хеша и для неизвестного email (выравнивание времени). Причина решения: пользователь с верным паролем иначе получает вводящее в заблуждение «неверный пароль» и не может понять, что делать; безопасность не страдает. Уже выданный токен отключённого пользователя на любом маршруте - 401 `UNAUTHENTICATED` (раздел 1.2, заморожено); отдельного 403 для токена нет. Клиент: на `ACCOUNT_DISABLED` показать `message`, не стирать введённый email, не повторять запрос автоматически.

**Q3. 429 на логине (A18-22).** `429 RATE_LIMITED` - уже заморожен в 1.2/1.4/17.3; отдельного кода для логина нет. Обязательный заголовок `Retry-After: <целое число секунд>` (>= 1); дублируется в теле `details: {"retry_after_seconds": 30}`. Лимит считается по паре «IP + нормализованный email» и по IP отдельно; значения - конфигурация, не контракт. Лимит применяется и к неудачным, и к успешным попыткам; ответ 429 не раскрывает, существует ли email. Клиент: блокирует кнопку на `retry_after_seconds` (при отсутствии поля читает заголовок; по умолчанию 30 с), показывает обратный отсчёт, автоповтор не делает. Тот же формат у 429 на register, upload, `/ai/*`, `/optimization/run`.

**Q1** - формат `field` в 422: см. 18.1.

### 18.10 Что изменено относительно разделов 1-17

- Добавлен код `403 ACCOUNT_DISABLED` (Q2); пункт A17-6 («неактивный получает `INVALID_CREDENTIALS`») заменён: 403 только после верного пароля; текст 17.3 в последнем абзаце следует читать с этой поправкой.
- Формат `field` для вложенных путей определён (18.1); набор `errors[].code` расширен и заморожен.
- Поведение `GET /materials` по умолчанию: архив скрыт (A18-8).
- Добавлен маршрут `DELETE /materials/{id}/images/{image_id}` (P1).
- Остальное (версия в теле, multipart, лимиты фото, 409 `IMAGE_LIMIT_REACHED`, статусы) - подтверждение ранее замороженного, без изменений.

### 18.11 Что backend должен сделать до интеграции Фазы 2

Порядок последовательный (одна миграционная линия): BE-01 (конверт ошибок, `request_id`, обработчик 422 в формате 18.1) -> BE-02 (login с 403/429) -> BE-03 (материалы: 18.3-18.6, 18.8) -> BE-04 (изображения: 18.7). Обработчик 422 должен преобразовать `loc` Pydantic в путь 18.1: отбросить первый сегмент `body`/`query`/`header`/`form`, остальные соединить точкой. До реализации клиент использует моки и не интегрируется.

### 18.12 Допущения раздела 18

- A18-1: путь `field` - точечная нотация от корня тела, индексы числовые, без префикса.
- A18-2: ошибка всего объекта - `field: ""`.
- A18-3: набор `errors[].code` (18.1).
- A18-4: сервер возвращает все ошибки валидации сразу.
- A18-5: неверный формат UUID в пути - 404.
- A18-6: лимит JSON-тела 64 KB.
- A18-7: `q` экранирует `%` и `_`.
- A18-8: архивные партии скрыты из `GET /materials` по умолчанию для enterprise.
- A18-9: `POST /materials` без идемпотентности.
- A18-10: города - свободный текст, без справочника.
- A18-11: заголовок `Location` в 201.
- A18-12: `version` в теле PATCH, `If-Match` не используется.
- A18-13: PATCH без фактических изменений не увеличивает `version`.
- A18-14: `details.blocked_fields` в `ACTIVE_OBLIGATIONS` (для PATCH).
- A18-15: при обязательствах разрешены `name`, `price_per_kg`, `composition`, `scrap_size`.
- A18-16: сдвиг `sort_order` при занятом значении.
- A18-17: `details.max_images` в `IMAGE_LIMIT_REACHED`.
- A18-18: сервер удаляет EXIF при сохранении фото.
- A18-19: `DELETE` фото - P1, предварительный контракт.
- A18-20: набор значений `details.missing` в `PUBLISH_REQUIREMENTS_NOT_MET`.
- A18-21: `403 ACCOUNT_DISABLED` только после верного пароля.
- A18-22: `details.retry_after_seconds` в 429 и ключ лимита «IP + email».

## 19. Lifecycle - publish, archive

Статус: предварительная заморозка контракта жизненного цикла партии для мобильного клиента (Приоритет 1). Дата записи: 2026-11-07. Владелец: backend-engineer. Требует утверждения оркестратора. **Не реализовано**: это контракт, а не описание работающего кода. Новых маршрутов нет: уточняются 8.7 и 8.8 (оба помечены «дополнительный», решение D-11: publish - P0, archive - P1). При расхождении с 8.7, 8.8, 17.x, 18.8 приоритет у раздела 19. Допущения помечены A19-n (список в 19.8).

### 19.1 Общие правила обоих маршрутов

- Роль: `enterprise`. Порядок проверок: 401 `UNAUTHENTICATED` -> 429 `RATE_LIMITED` -> 403 `FORBIDDEN` (buyer вызывает publish/archive: действие запрещено роли, ответ одинаков для любой партии, существующей или нет, поэтому существование партии не раскрывается) -> 404 `NOT_FOUND` (для enterprise: чужая, несуществующая, неверный UUID, раздел 18.2) -> 422 `VALIDATION_ERROR` (тело) -> блокировка строки партии `SELECT ... FOR UPDATE` -> 409 `VERSION_CONFLICT` -> повтор/переход (19.3, 19.5) -> предусловия (19.2, 19.4).
- Тело `MaterialVersionIn` (лишние поля - 422 `extra_forbidden`): `{ "version": int }`, **обязательно**, >= 1. Нет поля или не int - 422 `VALIDATION_ERROR` (`field: "version"`, `required` / `invalid_type`). Значение не равно текущему - 409 `VERSION_CONFLICT`, `details: {"current_version": 4}`, ничего не меняется (раздел 4). Клиент после 409 перечитывает `GET /materials/{id}` и сам решает, повторять ли.
- `Idempotency-Key` не используется: повтор безопасен по состоянию (19.3, 19.5), A19-1.
- Операции не вызывают AI, solver и фоновые задачи; всё выполняется в одной транзакции.
- `429 RATE_LIMITED`: заголовок `Retry-After: <целое секунд >= 1>` и `details: {"retry_after_seconds": N}` (формат 18.9 Q3). Лимит по пользователю, значение - конфигурация (A19-2). Клиент блокирует кнопку на это время, автоповтор не делает.
- Ответ 200 - полный `MaterialOut` (3.6) с актуальными `status`, `version`, `balance`, `is_confirmation_current`. Клиент заменяет локальную карточку этим ответом и не вычисляет статус сам.

### 19.2 POST /materials/{id}/publish

Назначение: `draft` -> `available`. Произвольный PATCH статуса запрещён (18.8).

Предусловия публикации (все проверяются на текущей `version` внутри транзакции):

| `details.missing[]` | Условие выполнено, когда |
| --- | --- |
| `material_type` | не null |
| `total_kg` | `total_kg > 0` **строго** (0.000 не проходит; на черновике 0 допустим, 19.6) |
| `condition` | не null |
| `city` | не null |
| `images` | >= 1 фото (CLAUDE.md §5: фото обязательно перед публикацией) |
| `confirmation` | `is_confirmation_current = true`: `POST /confirm` выполнен на текущей `version` и после последнего изменения характеристик или фото |

Состав не требуется (`composition = null` допустим). `price_per_kg` не требуется (null = цена не задана).

Не выполнено хотя бы одно - `422 PUBLISH_REQUIREMENTS_NOT_MET`, партия не меняется. `details.errors[]` (формат 18.1: `field` = элемент `missing`, `code` = `required`) и `details.missing` присутствуют оба и согласованы; `missing` - полный список всех невыполненных условий, порядок как в таблице (сервер возвращает все сразу, A18-4):

```json
{ "error": { "code": "PUBLISH_REQUIREMENTS_NOT_MET", "message": "Для публикации заполнены не все данные.",
  "details": { "missing": ["total_kg", "images", "confirmation"],
    "errors": [
      { "field": "total_kg", "code": "required", "message": "Укажите массу больше нуля." },
      { "field": "images", "code": "required", "message": "Добавьте хотя бы одно фото." },
      { "field": "confirmation", "code": "required", "message": "Подтвердите характеристики." } ] },
  "request_id": "9f0c2c9e-6d2b-4b5a-8f3e-2f1d5e7a1c11" } }
```

Отдельный код `CHARACTERISTICS_NOT_CONFIRMED` **не вводится**: отсутствие или устаревание подтверждения - элемент `confirmation` в `details.missing` того же 422. Причина: клиенту нужен один чек-лист «Что осталось» за один ответ (18.8); два кода разной категории (422 и 409) заставили бы делать два запроса. `PRECONDITION_FAILED` для публикации не используется. Это согласуется с 8.7 и 18.8.

Успех: `200 MaterialOut`, `status = "available"`, `version` **не изменяется** (публикация не меняет входные характеристики; A19-3), `confirmed_at/by` не меняются, `balance` не меняется. Сервер ставит статус единым сервисом статусов (CLAUDE.md §5); фактически на момент публикации обязательств нет, поэтому результат всегда `available`.

Коды: 200, 401, 403, 404, 409 (`VERSION_CONFLICT`, `INVALID_TRANSITION`), 422 (`VALIDATION_ERROR`, `PUBLISH_REQUIREMENTS_NOT_MET`), 429.

### 19.3 Повтор publish (идемпотентность)

Выбрано: **повтор возвращает 200 с текущим состоянием, а не 409.** Причины: мобильная сеть - клиент может не получить первый ответ и повторить; повтор не должен выглядеть ошибкой и не должен ломать UI; побочных эффектов нет (A19-4).

| Текущий `status` при `version` из запроса == текущей | Результат |
| --- | --- |
| `draft` | Публикация (19.2) |
| `available`, `partially_allocated`, `reserved`, `completed` | 200 `MaterialOut` без изменений: ничего не записывается, `updated_at` не меняется, второго события, записи или нового статуса нет. Предусловия 19.2 при этом **не** перепроверяются |
| `archived` | 409 `INVALID_TRANSITION` (из архива публикации нет, 19.5) |

Если `version` устарела - сначала 409 `VERSION_CONFLICT` (даже для уже опубликованной партии). Так как publish не увеличивает `version`, обычный повтор после потерянного ответа имеет ту же `version` и получает 200. Если между попытками владелец изменил характеристики (партия вернулась в `draft`, `version` выросла) - повтор со старой `version` получает 409 `VERSION_CONFLICT`, а не молчаливую публикацию изменённых данных.

### 19.4 POST /materials/{id}/archive

Назначение: скрыть партию владельцем. Предусловие (CLAUDE.md §5: archived только при отсутствии активных резервов): `held_kg = 0`. Иначе `409 ACTIVE_OBLIGATIONS`, `details: {"held_kg": "20.000", "reason": "HELD_RESERVATIONS"}` (`reason` - A19-5; формат массы - decimal-строка). Сначала владелец отменяет подтверждённые резервы (`PATCH /reservations/{id}`, action `cancel`), затем архивирует.

- Допустимые исходные статусы: `draft`, `available`, `partially_allocated`, `completed` (при `held_kg = 0`). Для `reserved` `held_kg > 0` по определению, поэтому ответ всегда `ACTIVE_OBLIGATIONS`, не `INVALID_TRANSITION`.
- `transferred_kg > 0` или `internally_used_kg > 0` архивацию **не** блокируют (это свершившиеся факты, а не активные резервы); баланс и impact-записи сохраняются, `balance` не меняется (A19-6). Аналитика остаётся прежней.
- Резервы `pending` (не удерживают запас, раздел 4) при архивации сервером переводятся в `cancelled` в той же транзакции с `cancel_reason = "MATERIAL_ARCHIVED"`, чтобы у покупателя не оставалось висящих заявок (A19-7; без фонового процесса).
- Успех: `200 MaterialOut`, `status = "archived"`, `version` **увеличивается на 1** (архивация меняет видимость и инвалидирует сохранённые планы: `is_stale = true`, A19-8). `confirmed_at/by` сохраняются.
- Повтор: партия уже `archived` и `version` совпадает с текущей - 200 без изменений; иначе (устаревшая `version`) - 409 `VERSION_CONFLICT`. Из-за инкремента `version` повтор после потерянного ответа несёт старую `version` и получает `VERSION_CONFLICT` - клиент при этом перечитывает карточку и видит `archived` (A19-9; поэтому для archive клиент трактует 409 `VERSION_CONFLICT` как «перечитать и сверить»).
- Разархивации нет (A19-10).

Коды: 200, 401, 403, 404, 409 (`VERSION_CONFLICT`, `ACTIVE_OBLIGATIONS`), 429. `INVALID_TRANSITION` для archive не возвращается.

### 19.5 Машина состояний партии: переходы и ошибки

Статус хранится/пересчитывается сервером (18.8). Инициатор «Пользователь» - явная операция владельца; «Система» - побочный эффект резерва и остатков.

| Из | В | Инициатор и операция | Условие |
| --- | --- | --- | --- |
| `draft` | `available` | Владелец: `publish` | 19.2 |
| `draft` | `archived` | Владелец: `archive` | всегда (`held_kg = 0`) |
| `available` | `partially_allocated` | Система: confirm резерва (часть массы), internal-use, transfer | `available_kg > 0` после операции |
| `available` | `reserved` | Система: confirm резерва на всю свободную массу | `available_kg = 0`, `held_kg > 0` |
| `available` | `completed` | Система: internal-use / transfer на всю массу | `held_kg = 0`, `available_kg = 0` |
| `available` | `draft` | Система: PATCH входных характеристик или фото | `held_kg = 0` и `transferred_kg = 0` (раздел 4); подтверждение сброшено |
| `available` | `archived` | Владелец: `archive` | `held_kg = 0` |
| `partially_allocated` | `available` | Система: cancel резерва | `available_kg = total_kg` |
| `partially_allocated` | `reserved` / `completed` | Система: резерв / передача / использование остатка | по формулам 18.8 |
| `partially_allocated` | `archived` | Владелец: `archive` | `held_kg = 0` |
| `reserved` | `available` / `partially_allocated` | Система: cancel резерва | по остаткам |
| `reserved` | `completed` | Система: transfer + завершение | `held_kg = 0`, вся масса выбыла |
| `completed` | `archived` | Владелец: `archive` | всегда |
| `archived` | любой | запрещено | - |

Запрещённые переходы и ответы:

| Попытка | Ответ |
| --- | --- |
| `publish` из `archived` | 409 `INVALID_TRANSITION`, `details: {"from": "archived", "action": "publish"}` |
| `publish` из остальных не-`draft` | 200 без изменений (19.3), не ошибка |
| `archive` при `held_kg > 0` (включая `reserved`) | 409 `ACTIVE_OBLIGATIONS` |
| PATCH, `confirm`, `images`, `internal-use` для `archived` партии | 409 `INVALID_TRANSITION`, `details: {"from": "archived", "action": "<patch|confirm|images|internal-use>"}` (A19-11) |
| `confirm` / `internal-use` для `draft`, `reserved`, `completed` и пр. по остаткам | как раньше: `confirm` допустим на `draft` и опубликованной; `internal-use` без свободной массы - 409 `INSUFFICIENT_STOCK` |
| `POST /reservations` на партию не в `available` / `partially_allocated` | 404 `NOT_FOUND` (buyer не видит такую партию, A17-8) |
| любое явное изменение статуса через PATCH | 422 `extra_forbidden` (`status` read-only, 18.8) |

`INVALID_TRANSITION` в `details` всегда содержит `from` (текущий `status`) и `action`; клиент не ветвится по тексту сообщения. Статусы `reserved`, `partially_allocated`, `completed` пользователь напрямую не задаёт ни одним маршрутом.

### 19.6 Масса: черновик и публикация (согласование клиента и сервера)

Правило: **`total_kg = 0.000` допустим только у `draft`** (как в 18.4: по умолчанию `"0.000"`, сервер принимает 0 при создании и PATCH черновика). **`publish` требует `total_kg > 0` строго**; при нуле - 422 `PUBLISH_REQUIREMENTS_NOT_MET`, `missing` содержит `total_kg`, `errors[].field = "total_kg"`. Это не `VALIDATION_ERROR`: само значение 0 для черновика корректно.

Следствия для опубликованной партии (`available`, `partially_allocated`, `reserved`, `completed`): PATCH с `total_kg = 0` для партии вне `draft` - 422 `VALIDATION_ERROR` (`field: "total_kg"`, `code: "out_of_range"`), чтобы опубликованная партия не имела нулевой массы (A19-12). Снижение `total_kg` ниже `held + transferred + internally_used` - по-прежнему 409 `ACTIVE_OBLIGATIONS` (раздел 4). Клиент на форме разрешает 0 только в режиме черновика, а кнопку «Опубликовать» не блокирует локально по массе: источник истины - ответ сервера и `details.missing`.

### 19.7 Кто и когда видит партию

| Статус | enterprise-владелец (`MaterialOut`) | buyer (`MaterialPublicOut`) |
| --- | --- | --- |
| `draft` | да | нет (404 по id, нет в списке) |
| `available` | да | **да** |
| `partially_allocated` | да | **да**, и только если `available_kg > 0` (по определению 18.8 так и есть) |
| `reserved` | да | нет |
| `completed` | да | нет |
| `archived` | да, только при `status=archived` (A18-8) | нет |

Условие выдачи buyer в `GET /materials` и доступа по `GET /materials/{id}`: `status IN ('available','partially_allocated') AND available_kg > 0`. Иначе список не содержит партию, а прямой запрос - 404. Buyer видит только опубликованные поля: в `MaterialPublicOut` нет `held_kg`, `transferred_kg`, `internally_used_kg`, `confirmed_by`, `organization_id` продавца вне допустимых по 17.6 полей, контактов (контакты - только участникам сделки). Видимость вычисляется на каждом запросе по текущему состоянию: после `archive` или после резерва всей свободной массы партия пропадает из выдачи buyer сразу, без кэша на сервере. Покупатель, у которого уже есть заявка на такую партию, видит её через `GET /reservations` (данные сделки), а не через каталог. Клиент buyer, открывший карточку из устаревшего списка, получает 404 и показывает «Партия больше недоступна» с возвратом к каталогу.

### 19.8 Допущения раздела 19

- A19-1: publish и archive без `Idempotency-Key`; безопасность повтора - по состоянию и `version`.
- A19-2: rate limit на publish/archive есть (по пользователю), значения - конфигурация; раздел 1.4 дополняется этими маршрутами.
- A19-3: publish не увеличивает `version` (входные характеристики не менялись); повтор с той же `version` идемпотентен.
- A19-4: повтор publish опубликованной партии - 200 без изменений и без побочных эффектов (замена 409 `INVALID_TRANSITION` из 8.7 для этого случая).
- A19-5: `ACTIVE_OBLIGATIONS` при archive содержит `details.held_kg` и `details.reason = "HELD_RESERVATIONS"`.
- A19-6: `transferred_kg` / `internally_used_kg` не блокируют archive.
- A19-7: при archive `pending` резервы автоматически отменяются (`MATERIAL_ARCHIVED`) в той же транзакции.
- A19-8: archive увеличивает `version` и помечает планы устаревшими.
- A19-9: повтор archive со старой `version` - 409 `VERSION_CONFLICT`; с актуальной на уже архивной - 200.
- A19-10: разархивации в MVP нет.
- A19-11: любые изменяющие операции над `archived` партией - 409 `INVALID_TRANSITION`.
- A19-12: PATCH `total_kg = 0` вне `draft` - 422 `out_of_range`.
- A19-13: код `CHARACTERISTICS_NOT_CONFIRMED` не вводится; подтверждение - элемент `confirmation` в `details.missing`.
- A19-15: `ReuseUse` (потребности покупателя) приведён к `ReuseType` (раздел 2); затрагивает `uses` в 3.8 и 9.2.
- A19-14: порядок проверок 19.1 (роль раньше владения; `VERSION_CONFLICT` раньше предусловий).
- A19-16 (решение LC-75): buyer, запрашивающий чужую или скрытую партию на чтение (`GET /materials/{id}`, `POST /reservations` и т. п.), получает 404 `NOT_FOUND` (CLAUDE.md §9), не 403. 403 `FORBIDDEN` - только для действий, запрещённых роли (buyer вызывает publish, archive и другие enterprise-маршруты), независимо от партии.

## 20. Состояние реализации BE-01..BE-03 (2026-11-07)

Реализовано в `backend/` и покрыто тестами на PostgreSQL: `GET /health`; `POST /auth/register`, `POST /auth/login`; `GET/PATCH /organizations/me`; `GET/POST /materials`; `GET/PATCH /materials/{id}`; `POST /materials/{id}/images`; `POST /materials/{id}/confirm`; `POST /materials/{id}/publish`; `POST /materials/{id}/archive`. Остальные маршруты (BE-04..BE-09, AI, optimization) не реализованы. Утверждения «ничего не реализовано» в разделах 17-19 относятся к состоянию на момент их записи.

Отличия и уточнения реализации (не меняют форму DTO из разделов 1-19):

- A20-1: `POST /auth/register` с `role=enterprise` и `activity_type=recycler` - 422 `VALIDATION_ERROR`, `field: "organization.activity_type"` (тот же запрет, что в 7.2 для PATCH).
- A20-2: `POST /materials/{id}/confirm` с непустым `analysis_id` пока всегда 409 `PRECONDITION_FAILED`, `details.reason = "ANALYSIS_NOT_FOUND_FOR_MATERIAL"` (таблицы анализов нет до AI-02).
- A20-3: `is_confirmation_current` = `confirmed_at IS NOT NULL`; `confirmed_*` сбрасываются при изменении `material_type`, `composition`, `scrap_size`, `condition`, `city`, `total_kg` и при загрузке фото (раздел 4). Изменение только `name`/`price_per_kg` увеличивает `version`, подтверждение сохраняется.
- A20-4: проверка состояния опубликованной партии для PATCH `total_kg = 0` (19.6) выполняется после блокировки строки, но до сравнения `version`.
- A20-5: для обычных ошибок HTTP вне набора 1.2 (неизвестный маршрут - 404 `NOT_FOUND`; неверный метод - 405 `METHOD_NOT_ALLOWED`; прочее - `HTTP_ERROR`) используется тот же конверт. Клиент ветвится по HTTP-статусу.
- A20-6: порядок «404 затем 422» из 19.1 соблюдён не полностью: ошибка формы тела (422) возвращается раньше 404 по владению (FastAPI валидирует тело до обработчика). Роль (403) и лимит (429) проверяются раньше тела.
- A20-7: при архивации `pending`-резервы пока не отменяются (резервов ещё нет); обязательство реализовать в BE-06 (A19-7).
- A20-8: `GET /materials/{id}/images/{image_id}/url` (8.5) не реализован; нужен адаптер Storage с подписанными ссылками (BE-04, BLK-03). Фото сейчас пишутся в локальную папку `STORAGE_LOCAL_DIR`, в БД хранится только object key.
- A20-9: лимит размера multipart проверяется по заголовку `Content-Length` (10 MB + 64 KB на обрамление) и повторно по фактически прочитанным байтам; запрос без `Content-Length` (chunked) читается до 10 MB + 1 байт. Лимит JSON 64 KB проверяется только по `Content-Length`.
- A20-10: rate limit хранится в памяти процесса (один инстанс); ключ логина - IP и IP + email. IP берётся из соединения, заголовки прокси не учитываются.
- A20-11: валидация email - простая проверка формы `local@domain.tld` (без DNS и без запрета служебных зон, чтобы `*.test` из примеров проходил).
