# Demo Mode, Publish Flow and AI Analysis Screen

Status: draft. Responds to device E2E defects DEV-02, DEV-03, DEV-04, DEV-05 (`docs/qa/device-e2e-2026-11-07.md`). Extends `phase-2-materials.md`, `ai-results.md`, `states.md`; colours only from `tokens.md`. UI copy Russian, identifiers English. No endpoints are proposed; fields the API may lack are listed in Open questions. The server enforces every rule; a hidden button is a convenience, not protection.

Scope guard: no payments, delivery, chat, CO2, percentages, invented numbers. No CTA for functions outside the MVP.

## 1. Demo mode

### 1.1 Banner (all screens)

- Persistent, not dismissible, on every screen including login, in the demo build (`USE_DEMO_DATA=true`) and whenever the server reports demo mode `[dependency: see Q-D1]`. It is part of the app shell above the top app bar content, inside the safe area. Scrolls with nothing: fixed.
- Text: "Демо: синтетические данные, не реальные".
- Icon `science` (flask), 24 px, left. Colour pair `value-demo-*`: `#5B5048` on `#EFE6DE` (6.345), 1 px bottom border `outline` `#857A71`, with the diagonal-stripe pattern limited to a 8 px strip at the left edge (pattern is decoration; text and icon carry meaning).
- Height: at least 40 px visible; text `labelLarge` 14/20, wraps to 2 lines at 200% scale, never truncated.
- Screen reader: banner is a landmark-like region read once on screen entry as "Демо-режим. Синтетические данные, не реальные." Not a live region.
- Not orange: brand orange is never used for the banner, so it is not confused with a primary action.
- Values on cards keep their own "Демо" badge (`ai-results.md`); the banner does not replace it.

### 1.2 Reset demo data

- Location: Profile screen, section "Демо-режим", visible only in demo. Button label: "Сбросить демо-данные" (secondary/outlined, 48 px, `primary-text` `#9A3F00` label).
- Dialog (centered on laptop, full-screen sheet on phone):
  - Title: "Сбросить демо-данные?"
  - Body: "Все изменения в демо будут удалены: созданные партии, фото, подтверждения и результаты анализа. Данные вернутся к исходному набору. Реальные данные это не затрагивает."
  - Buttons: "Отмена" (default focus), "Сбросить" (destructive, `error` `#B3261E` fill with white label 6.536). Safe action first in focus order.
- During request: "Сбросить" disabled, label "Сброс…", dialog not closable by tap outside; second submit impossible.
- Success: snackbar "Демо-данные сброшены." (announced), app returns to the catalog.
- Error: dialog stays, message from the envelope or "Не удалось сбросить демо-данные. Повторите позже." with "Повторить".
- In the demo build without a server, the reset is local; the same texts apply. In API mode the control does not exist (server must also refuse; Q-D1).

### 1.3 What is not available in demo

- Deals, requests, reservations, transfer, receipt, internal use: no buttons rendered anywhere in demo (buyer request form, "Подать заявку", reserve/confirm actions).
- Where such a block would appear, show one inert text (not a button, not focusable): "В демо сделки не создаются."
- Matching and plan screens are not implemented yet (QA: MT1, OP1, RS1); do not show placeholder CTAs. A row with chip "Скоро" is allowed as in `phase-2-materials.md` only if it is plain text.
- Not hidden in demo: login, catalog, create/edit, photo step, confirm, publish, archive, AI analysis (section 3). These are the demo end-to-end path (DEV-04).

## 2. Flow: create, photo, confirm, publish, catalog, archive

Applies to demo and API; differences are marked.

| # | Screen | Action / button | State outcomes |
|---|---|---|---|
| 1 | S04 Create, step 1-3 | "Далее"; "Сохранить черновик" always available | loading: busy label "Сохранение…"; error: field texts section 4, banner "Проверьте поля формы."; success: snackbar "Черновик сохранён.", opens S05 draft |
| 2 | S04 step 4 / S05 photo section | "Добавить фото" | before first save: "Сначала сохраните черновик, затем добавьте фото."; tile uploading "Загрузка фото…"; tile error with "Повторить"; success tile thumbnail. Demo: see below |
| 3 | S05 draft | "Подтвердить характеристики" | dialog summary `materials.confirm.summary`; busy "Отправка…"; success "Характеристики подтверждены." and provenance "Подтверждено, {автор}, {дата}"; 409 version: banner "Партия изменилась, обновить данные." |
| 4 | S05 draft | "Опубликовать" (only when checklist complete) | busy "Отправка…"; success "Партия опубликована.", status chip "Доступно"; 422: checklist updated from server |
| 5 | S03 Catalog | card of the published batch | appears with chip "Доступно" and "Свободно: {N} кг" |
| 6 | S05 | "Архивировать" | dialog "Архивировать партию? Она исчезнет из каталога покупателей." buttons "Отмена" / "Архивировать"; success "Партия перенесена в архив."; 409 active holds: "Нельзя архивировать: по партии есть активные резервы." |

Demo decisions that unblock DEV-04 `[orchestrator decides, Q-D2]`: the spec requires that in demo (a) "Добавить фото" lets the user pick a photo from a bundled synthetic set or the device, kept locally, labelled "Демо: фото сохраняется только на этом устройстве" under the tile; (b) "Подтвердить характеристики" works locally and records the demo user as author. The message "Демо: подтверждение недоступно." must disappear. If the orchestrator decides otherwise, the demo path stops at the checklist and the checklist must say so honestly.

### Publish checklist (no photo and other gaps)

Shown on S05 for a draft instead of "Опубликовать" while any item is open. Title "Что осталось до публикации". Each row has icon plus text (`check_circle` + "Выполнено" or `cancel` + "Не выполнено" as screen-reader text), so not colour only.

| Item text | Open-state hint under the item | Row action (working link, 48 px) |
|---|---|---|
| Добавлено хотя бы одно фото | "Добавьте фото партии, чтобы опубликовать." | "Добавить фото" (goes to photo section) |
| Указаны тип, состояние и город | "Укажите: {перечень недостающих}." | "Изменить" |
| Масса больше нуля | "Укажите массу больше нуля." | "Изменить" |
| Характеристики подтверждены | "Проверьте и подтвердите характеристики." | "Подтвердить характеристики" (disabled with visible reason until the other fields are filled, since confirmation covers them) |

Below the list: "Опубликовать можно после выполнения всех пунктов." The draft card in the catalog shows "Нет фото" placeholder; it does not block saving. A draft without a photo is a valid state (empty state of the photo section: "Фото пока нет. Фото можно добавить позже, но для публикации нужно хотя бы одно.").

Caption under status chip for draft: "Не виден покупателям."

## 3. AI analysis screen (S06), demo and API

Entry: row "Анализ ИИ" on S05 owner view becomes an active button "Проанализировать фото" once the batch has at least one photo (replaces the inert "Скоро"; until the client implements it, the row stays inert). Without photo: plain text "Для анализа нужно фото." (no button). Buyer never sees it.

### 3.1 Notice plates (always visible, not dismissible)

| Mode | Plate text | Style |
|---|---|---|
| Demo | "Симуляция" with the line "Это пример результата, а не ответ реального сервиса ИИ." | `value-demo-*` pair, icon `science` |
| API | "ИИ-результат, требует проверки" | `value-suggested-*` pair `#3B4BA0` on `#E6E9F8` (6.435), dashed border, icon `auto_awesome` |

Both modes additionally keep the standing notice from `ai-results.md`: "ИИ не определяет состав, вес, прочность и безопасность материала." Reading order: banner, plate, notice, content.

### 3.2 States

| State | Display | Actions |
|---|---|---|
| pending / processing (progress) | Indeterminate progress bar plus text "Анализ выполняется…" (pending: "Анализ поставлен в очередь…"). No percent, no time estimate. Live region polite announces the change of text once. | "Закрыть" (analysis continues; result is available on return). No second-start button. |
| completed | Suggested features and reuse options, each with its reason and the label "Предложение ИИ" (see 3.3). Below, the confirmation block. | "Применить и подтвердить" only as a human action (section 3.4). |
| failed | `error` panel, icon `error`: "Анализ не удался." plus the server message or fallback "Не удалось выполнить анализ. Повторите попытку." and, for 5xx, "Код обращения: {request_id}". | "Повторить" (busy "Отправка…"). Manual entry and confirmation stay available: "Вы можете подтвердить характеристики вручную." |
| interrupted | Shown as failed. Text exactly: "Анализ прерван. Запустите заново." | "Запустить заново" is the retry label here; same lock rules. |
| unavailable (AI off or 503) | "Анализ ИИ сейчас недоступен. Каталог и ручной ввод работают." | no analysis button; "Подтвердить характеристики" remains. |
| stale (input changed) | warning pair with icon `warning`: "Данные партии изменились. Запустите анализ заново." | "Запустить заново"; old result is not confirmable. |

Other common states follow `states.md` (loading skeleton, 401, 403/404, 429 "Слишком много запросов. Повторите через минуту.").

### 3.3 Result content rules

- Never use the words "подтверждено" or the green confirmed style for AI content until the person presses the confirm button; at that moment the state changes to `value-confirmed-*` with author and date.
- Confidence: qualitative only, in words: "Уверенность: высокая / средняя / низкая / неизвестно" (icon plus text; no colour-only coding, no percentage, no bars, no stars, no numeric score). If the server gives a number, it is not shown `[Q-D3]`.
- Each feature (цвет, рисунок, фактура) and each reuse option shows: value, "Предложение ИИ" label, suitability in words, reason ("Почему: {причина}").
- Composition row, always: "Состав: Неизвестно — по фото не определяется." The person may enter composition manually; entered value is shown with its own label "Указано вами".
- Unknown values show "Неизвестно", never an empty cell or a guess.
- Demo results additionally carry the "Демо" badge on every value.

### 3.4 Confirmation block

- Heading "Ваша проверка". Fields are editable copies; suggested value and the person's value are shown side by side (labels "Предложение ИИ" / "Ваше значение").
- Button "Подтвердить характеристики" (48 px). The summary text is `materials.confirm.summary`. After success: "Характеристики подтверждены." with author and date.
- Not pressing the button leaves the batch not confirmed; the checklist item stays open.

## 4. Validation messages (DEV-02)

Rule: one style. Missing text input: "Укажите {что в винительном падеже}." Missing choice: "Выберите {что}." Wrong format: "Введите {что} …" with a short hint. No field-name prefix ("Название: …" is forbidden), no "обязательное поле". Texts end with a period, are under the field, and are tied to it for screen readers. Client checks format only; the server decides.

### 4.1 Materials form (save draft / publish requirement)

| Field | Condition | Text |
|---|---|---|
| Название | empty (draft requirement) | Укажите название партии. |
| Название | too long | Слишком длинное значение. Максимум {n} символов. |
| Тип материала | not chosen (publish) | Выберите тип материала. |
| Состояние | not chosen (publish) | Выберите состояние. |
| Масса, кг | empty (publish) | Укажите массу в кг. |
| Масса, кг | not a number | Введите число, например 12,5. |
| Масса, кг | negative | Значение не может быть отрицательным. |
| Масса, кг | zero or less (publish/server) | Масса должна быть больше нуля. |
| Масса, кг | too many decimals | Укажите не больше трёх знаков после запятой. |
| Город | empty (publish) | Укажите город. |
| Размер обрезков | too long | Слишком длинное значение. Максимум {n} символов. |
| Состав | too long | Слишком длинное значение. Максимум {n} символов. |
| Цена за кг, KGS | not a number | Введите число, например 120,50. |
| Цена за кг, KGS | negative | Значение не может быть отрицательным. |
| Цена за кг, KGS | too many decimals | Укажите не больше двух знаков после запятой. |
| Фото | no photo (publish checklist only) | Добавьте хотя бы одно фото. |

Note: the QA run showed 5 highlighted fields on an empty submit; on "Сохранить черновик" only Название is blocking. If "Далее"/publish-oriented validation highlights the other fields, they use the texts above and the summary "Проверьте поля формы." The example numbers in hints are format examples, not data. Replaces `materials.form.err.nameRequired`-style keys where they differ.

### 4.2 Login form

| Field | Condition | Text |
|---|---|---|
| Email | empty | Укажите email. |
| Email | wrong format | Введите email в формате name@example.com. |
| Пароль | empty | Укажите пароль. |
| Form (server) | wrong credentials | Неверный email или пароль. |
| Form (server) | 429 | Слишком много попыток. Повторите через минуту. |
| Form (network) | no connection | Не удалось войти. Проверьте соединение и повторите. |

Behaviour (DEV-01): an error clears for a field as soon as its value changes and is re-checked on field blur and on submit; it never remains next to an already corrected value. The wrong-credentials error does not say which of the two was wrong.

## 5. Alignment (DEV-03)

- Single left edge: screen margin `space-4` (16 px) on phone, equal for title, step indicator, field labels, inputs, helper and error texts, section headings, photo block and action bar. Content is not indented by nesting padding; cards and sections inside the form use zero extra left padding, and card padding is inside the card border only.
- Fields: label above the input, `space-2` (8) label-to-input, `space-4` (16) between fields, `space-5` (24) between groups. Inputs are full width of the content column.
- Photo block "Фото партии": the heading starts at the same left edge as the field labels; the "Добавить фото" button and tiles start at that edge; tile grid gap `space-3` (12); first tile and button aligned to the edge, no offset. The ~190 px shift seen on the device is a defect, not a layout choice.
- Laptop (>= 840 per tokens.md; Q-P2-5 pending): form column left, photos column right, each column with the same internal left edge rule; max content width from tokens.
- Check: at 200% text scale and at 320 px width the left edges stay equal; QA verifies with a screenshot overlay.

## 6. Login and password saving (DEV-05)

- Users see no extra explanation or warning. Login fields keep standard labels "Email" and "Пароль", with the password visibility toggle labelled "Показать пароль" / "Скрыть пароль" (48 px).
- The browser/OS password manager is the user's own choice and is not blocked by the design for real accounts: no custom nagging, no banners about saving passwords.
- In demo builds, demo credentials are shown on the login screen in a plain text block under the banner: "Демо-вход: {email} / {пароль}" `[values are fixture data from the orchestrator, not invented here; Q-D1]` with a "Заполнить" action filling the fields. Flutter-developer disables autofill save prompts for the demo account only (autofill hints off in demo); the user never sees an explanation of this.
- After logout the fields are empty (QA A5 passed).

## 7. Accessibility

- Every control has a persistent visible label (banner, plates, dialogs, progress). Icon-only controls (password toggle) have an accessible name.
- Contrast: only token pairs from `tokens.md`: demo `#5B5048` on `#EFE6DE` (6.345); suggested `#3B4BA0` on `#E6E9F8` (6.435); error `#B3261E` on white (6.536); destructive button white on `#B3261E` (6.536); links `#9A3F00` (6.806); body `#1C1B1F`. Orange `#F08331` only as fill with `#1C1B1F` label. Ratios remain to be re-verified by tool (tokens.md section 0); QA X6 was not done.
- Touch targets at least 48x48 px with at least 8 px gap: banner has no interactive element; reset, dialog buttons, retry, checklist row actions, password toggle, photo tiles.
- No colour-only meaning: every state has icon and text (failed, interrupted, stale, demo, suggested).
- Status changes are announced: analysis progress to completed/failed via polite live region; errors under fields assertive; snackbars announced.
- No repeated submit: "Повторить", "Запустить заново", "Сбросить", "Подтвердить характеристики", "Опубликовать", "Войти" are disabled with a busy label during the request, and Enter uses the same lock; the server still protects against repeats.
- Focus: banner is not a tab stop; on dialogs focus starts on the safe button; after failed analysis focus moves to the error panel heading.
- Text scale 200%: banner and plates wrap, no clipping.

## Open questions

| # | Question | Who answers |
|---|---|---|
| Q-D1 | How does the client learn demo mode in API mode (flag on the server) and what are the demo login fixtures? `ai-results.md` Q3 already needs an AI mode field (mock vs live). Until answered, banner and "Симуляция" depend on the build flag only. | backend-engineer, orchestrator |
| Q-D2 | Approve demo-local photo pick and demo-local confirmation to unblock DEV-04 (section 2), or accept that the demo ends at the checklist? | orchestrator |
| Q-D3 | Does the AI result schema carry numeric confidence? If yes, confirm it is mapped to the four words and never displayed as a number (coordinate with `docs/ai-schema.md`). | backend-engineer, orchestrator |
