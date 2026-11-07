# Screens

Status: draft, `[PROVISIONAL]` fields until CON-01. State texts are in `states.md`; every screen implements all of: loading, empty, error, success, 409, 403 (and AI states where marked). Notation: "Primary" = the single primary action.

## Navigation

- Laptop (>= 1024 px): left sidebar. Phone (< 600 px): bottom bar with up to 4 items; the rest in "Ещё".
- Enterprise items: Главная, Партии, Заявки, Профиль. Buyer items: Главная, Каталог, Потребности, Заявки, Профиль (Профиль under "Ещё" on phone).
- Items for the other role are not rendered; the server still rejects direct access (403 screen).
- Token expiry: any 401 returns to S01 with "Сессия истекла. Войдите снова." and keeps no unsaved secrets; unsaved form text is kept in memory where possible.

## S01 Login / Registration
- Goal: authenticate. Role: public.
- Fields: Email, Пароль, (register) Название организации, Город, Роль (Предприятие / Покупатель), Вид деятельности (покупатель: мастерская / переработчик). No admin option.
- Primary: "Войти" / "Зарегистрироваться". Disabled and spinner during request.
- States: error shows envelope `message` (safe text) under the form; field errors (422) under fields; 409 "email занят" `[PROVISIONAL]`; 403 not applicable except inactive user: "Учётная запись отключена."; 429: "Слишком много попыток. Повторите позже."
- AI: n/a.

## S02 Dashboard
- Goal: separate view of registered, distributed, confirmed reuse, revenue, forecast. Roles: enterprise, buyer (own data). Details in `dashboard.md`.
- Primary (enterprise): "Добавить партию". Buyer: "Найти материал".
- Empty: all zeros with explanation and one onboarding CTA that works.
- Layout: cards in a grid (4 columns laptop, 1 column phone). Forecast block visually separate below facts.

## S03 Catalog
- Goal: find materials. Enterprise sees own (any status); buyer sees published only.
- Filters: Тип, Состояние, Город, Статус (enterprise). Phone: filters in a bottom sheet. Pagination "Показать ещё".
- Row/card: photo thumbnail, name, type, free mass "N кг", city, status chip, price "N KGS/кг" or "Цена не указана". No contacts for buyers.
- Primary: enterprise "Добавить партию"; buyer none (tap opens card).
- Empty: enterprise "Партий пока нет. Добавьте первую."; buyer "Пока нет опубликованных партий."
- 403: buyer opening a draft link: "Нет доступа к этой партии." (server may return 404; same screen).

## S04 Material create/edit with photos
- Goal: capture a draft. Role: enterprise (owner).
- Fields: Название, Тип, Состояние, Масса (кг), Город, Размер обрезков, Состав (необязательно, "Неизвестно" допустимо), Цена за кг (KGS, необязательно). Photos: up to 5, JPEG/PNG/WebP, up to 10 MB each (limits per CLAUDE.md §11, check with API).
- Primary: "Сохранить черновик". Secondary: "Далее: анализ" (shown only after a draft exists).
- Photo tiles: uploading (progress), uploaded, error (retry), remove. Reorder optional.
- 409: stale version -> banner with "Обновить данные" (reload server version; user's input shown for copy).
- Editing blocked fields when active obligations exist: fields are read-only with text "Нельзя изменить: есть активные заявки." (server enforces).
- Draft without photos is allowed; publish message lists the missing photo.

## S05 Material card
- Goal: show details and actions by role/status.
- Enterprise blocks: summary, photos, mass balance (Свободно / Удержано / Передано / Использовано внутри, all in кг, with total), characteristics split into "Подтверждено" and AI block link, actions.
- Enterprise actions by status: draft: "Опубликовать" (only if requirements met; otherwise checklist "Что осталось"), "Анализ", available: "Подбор покупателей", "План", "Использовано внутри", "Архивировать" (hidden while active reservations exist).
- Buyer: published fields only, quantity field (кг) + "Подать заявку". Contacts hidden until a deal exists.
- Statuses shown with text label and icon: Черновик, Доступно, Частично распределено, Зарезервировано, Завершено, В архиве (tokens and icons in `phase-2-materials.md` section 4; status is never a forecast).
- Phase 2 detail for S03, S04, S05 (flow, draft vs publish rules, card, role views, states, messages): `phase-2-materials.md`. It prevails over this section for these three screens. AI analysis is a non-interactive "Скоро" row in phase 2.
- 409: "Остаток изменился" on request/internal use.

## S06 AI analysis and confirmation
- Goal: show AI suggestions separately and let a human confirm. Role: enterprise owner. Full rules in `ai-results.md`.
- Layout: laptop two columns (left: photos and notice; right: suggestions + confirm form). Phone: stacked, confirm bar sticky at bottom.
- Primary: "Подтвердить характеристики", disabled during request; disabled with explanation if analysis is stale.
- States: pending/running (progress text, user may leave), failed (retry + manual), unavailable (manual only), stale (new analysis required).

## S07 Matching results
- Goal: show compatible requirements with reasons. Role: enterprise (own material).
- Item: buyer organization name (no contacts), score "N из 100" with components (Город, Применение, Покрытие спроса), possible volume "до N кг", reasons list. Rules version shown small: "Правила v[версия]".
- Excluded section (collapsed): "Не подходят" with reason per item.
- Requires confirmed characteristics: if not confirmed, show "Подтвердите характеристики, чтобы выполнить подбор." with a link to S06.
- Empty: "Подходящих покупателей не найдено." + reasons summary if available.
- Primary: "Построить план" (to S08).

## S08 Allocation plan
- Goal: recommendation, not a reservation. Role: enterprise (owner).
- Persistent banner: "План — рекомендация. Он не резервирует материал и не отправляет заявки."
- Content: solver status (Оптимально / Допустимое решение / Эвристика / Нет решения / Время вышло / Ошибка), method, per-direction table (Внутреннее использование, Продажа, Переработка): кг, ожидаемая чистая ценность KGS (label "ожидается"), remainder "Остаток: N кг", baseline comparison with difference, assumptions list with origin.
- "Допустимое решение" is never called optimal.
- Outdated plan (material version changed): "План устарел. Пересчитайте." with "Пересчитать"; stale plan values dimmed.
- Primary: "Рассчитать план" / "Пересчитать". Applying a plan: opens S05/S09 normal actions; no one-click apply.
- Errors: infeasible "Для выбранных данных допустимого плана нет."; timeout "Расчёт занял слишком много времени. Выберите меньше партий."

## S09 Requests and transactions
- Goal: run the request lifecycle. Both roles; each sees own side.
- List grouped by status tabs: Ожидают, Подтверждены, Переданы, Завершены, Отменены. Row: material, кг, agreed price KGS/кг (or "Цена не согласована"), status chip.
- Detail shows a stepper: Заявка -> Резерв -> Передача -> Получение; separate line "Использование подтверждено: N кг" (distinct from receipt).
- Actions by role and status (shown only when valid): seller: "Подтвердить резерв", "Отклонить" (reason), "Отметить передачу"; buyer: "Отменить заявку", "Подтвердить получение", "Подтвердить использование" (kg).
- Contacts of counterparty visible only on a confirmed or later request.
- 409 texts in `states.md`. Repeated tap does not create duplicates (button locked; server idempotent).

## S10 Buyer requirements
- Goal: manage demand. Roles: buyer, recycler (own only).
- Fields: Типы, Состояния, Мин. объём (кг), Макс. объём (кг), Бюджет (KGS/кг), Город, Способы применения, Активна (switch). `remaining_demand_kg` shown read-only as "Осталось спроса: N кг".
- Validation: min <= max, values >= 0, in-field messages: "Минимум не может быть больше максимума."
- Empty: "Потребностей нет. Добавьте, чтобы получать подходящие партии."
- Primary: "Сохранить".

## S11 Profile
- Goal: view/edit organization. Fields: Название, Контакты, Город, Вид деятельности (read-only), Email (read-only), Роль (read-only). Primary: "Сохранить". Secondary: "Выйти".
- 409 stale version if provided by API `[PROVISIONAL]`.

## Open questions

- Does GET materials return seller organization name for buyers? (backend-engineer)
- Photos: signed URLs expire; image tile reload behaviour on expiry (backend-engineer: refresh mechanism).
- Is the plan scoped to one or several materials in the UI? (optimization-engineer)
