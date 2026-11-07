# Phase 2: Textile Batches (Материалы / «Партии»)

Status: draft. Covers S03 (catalog), S04 (create/edit), S05 (batch screen) for the mobile-first Flutter build. Field names and error codes follow `docs/api.md` (read, not modified); items the API lacks are listed under Open questions. UI copy is Russian, identifiers English. No code, no endpoints proposed. Server enforces every rule; a hidden or disabled button is only a convenience.

Scope guard: no chat, payment, delivery, CO2 or forecast values anywhere in this phase. AI analysis is a non-interactive "Скоро" marker only. Matching, plan, requests, internal use are outside this phase and are not rendered as buttons.

## 1. Create / edit flow (S04)

Entry: "Создать партию" (catalog empty state and catalog top action). Phone: 4-step flow with a step indicator "Шаг N из 4" (text, not colour only). Laptop: the same four groups as sections on one page, no stepper. "Сохранить черновик" is available on every step and always sends the whole form.

| Step | Group title | Fields (visible label, unit) | Control |
|---|---|---|---|
| 1 | Основное | Название (обязательно для черновика), Тип материала, Состояние | text, dropdown, dropdown |
| 2 | Масса и место | Масса (кг), Город, Размер обрезков (необязательно), Состав (необязательно, "Неизвестно" допустимо) | decimal, text, text, text |
| 3 | Цена и описание | Цена за кг (KGS/кг, необязательно), Описание (необязательно) | decimal, multiline |
| 4 | Фото | Фото партии, до 5 | photo tiles |

Dropdown option labels (RU) for API enums `[PROVISIONAL, enum values are assumptions in api.md]`:
- Тип: cotton Хлопок; wool Шерсть; linen Лён; silk Шёлк; synthetic Синтетика; knit Трикотаж; denim Деним; mixed Смесовая ткань; other Другое.
- Состояние: unused Новое, не использовалось; good Хорошее; worn Б/у, следы износа; damaged Повреждённое.

Photos need a saved batch id. Step 4 before the first save shows the text "Сначала сохраните черновик, затем добавьте фото." with the button "Сохранить черновик". After save the tiles appear. Every upload changes the batch version; the client takes the new version from the response and uses it for the next save (no manual refresh).

### Required for saving a draft vs publishing (CLAUDE.md §5)

| Item | Save draft | Publish |
|---|---|---|
| Название | required | required |
| Тип материала | optional | required |
| Состояние | optional | required |
| Масса, кг | optional; if entered, >= 0 (0 allowed in draft) | required, > 0 |
| Город | optional | required |
| Цена за кг | optional; if entered, >= 0; empty means "не указана", never 0 | optional |
| Размер обрезков, Состав, Описание | optional | optional |
| Фото | not required | at least 1 |
| Подтверждение характеристик | not applicable | required and current |

Publishing is done on S05, not in the form. The form never blocks saving because publish requirements are missing. Entered values are still validated by format and range on save.

### Field errors

- Error text sits directly under its field, in `error` colour with an error icon and text (not colour only), linked to the field for screen readers.
- Client checks only format (non-number, negative, over length); the server stays authoritative. Server 422 `details.errors[].field` maps to the field; an unmapped error goes to the summary only.
- On a failed save: a summary at the top "Проверьте поля формы." plus focus moves to the first invalid field. On phone the stepper jumps to the step containing the first invalid field and the step indicator marks steps with errors by icon and text "есть ошибки".
- Helper line under mass: "Укажите массу в килограммах, например 12,5." (an example of format, not data). Under price: "Оставьте пустым, если цена не определена."
- Edit mode: leaving with unsaved changes asks "Выйти без сохранения?".

## 2. Catalog card (S03)

Contents in reading order: photo thumbnail (placeholder icon `image_not_supported` on neutral fill with text "Нет фото" if no images), name (titleMedium, max 2 lines, ellipsis), status chip (section 4), type and condition ("Хлопок · Хорошее"), mass line, city, price line.

| Element | Text pattern | Notes |
|---|---|---|
| Mass | "Свободно: {N} кг" | buyer sees `available_kg` only; owner sees the same on the card (balance only on the batch screen); draft shows the entered mass as "Масса: {N} кг" |
| City | "{город}" with `location_on` icon, or "Город не указан" (draft only) | |
| Price | "{N} KGS/кг" or "Цена не указана" | null is never shown as 0 |
| Seller | buyer only: organization name | no contacts |

Not on the card: version, CO2, forecast, plan value, score, held/transferred masses. The whole card is one touch target (min 48 px, in practice full card) with accessible name "Партия {название}, {статус}, свободно {N} кг, {город}"; no nested buttons on phone.

Filters (type, condition, city, status for owner, search by name) per `screens.md`; phone uses a bottom sheet. Owner-side only: "Создать партию" as the single primary action (FAB-style extended button on phone, top-right on laptop).

## 3. Batch screen (S05)

Section order (phone single column; the same order top to bottom on laptop, with the right column holding sections 1-2 sticky):

| # | Section | Owner sees | Buyer sees (`MaterialPublicOut` only) |
|---|---|---|---|
| 1 | Header: name, status chip, "Изменить" (owner) | yes; "Изменить" only for draft or when edit is allowed | name, status chip |
| 2 | Photos (carousel, "Фото {n} из {m}") | all photos, with add/remove in edit mode | photos |
| 3 | Что осталось до публикации (draft only, checklist) | yes | never |
| 4 | Характеристики: тип, состояние, город, размер обрезков, состав, цена за кг, описание | all fields; each with the label "Подтверждено, {автор}, {дата}" or "Не подтверждено" or "Требует повторного подтверждения" | published fields as returned; no confirmation author |
| 5 | Масса, кг: Всего, Свободно, Удержано, Передано, Использовано внутри | full balance from server, no client sums | only "Свободно: {N} кг" |
| 6 | Продавец | not shown (own batch) | organization name only; line "Контакты станут доступны после подтверждения заявки." |
| 7 | Анализ ИИ | one inert row "Анализ ИИ" with chip "Скоро"; not focusable as a button, no action | not shown |
| 8 | Действия | draft: "Подтвердить характеристики" (when not confirmed or stale), "Опубликовать", "Изменить"; available/partially_allocated: "Изменить", "Архивировать" (see 5.6); other statuses: none | none in this phase |

Rules:
- "Опубликовать" is shown for draft. If requirements are missing, the button is replaced by the checklist (section 3) with the text "Опубликовать можно после выполнения всех пунктов"; the checklist items are: Добавлено хотя бы одно фото; Указаны тип, состояние и город; Масса больше нуля; Характеристики подтверждены. Each item has a check/cross icon plus text. The server returns `PUBLISH_REQUIREMENTS_NOT_MET` with `details.missing`; if the checklist was out of date, show the server list.
- "Подтвердить характеристики" asks the human to review the displayed fields; it works without AI (analysis id is optional in the API). Summary text: "Вы подтверждаете характеристики партии. После подтверждения они используются в подборе и плане." Any change to key fields makes the label "Требует повторного подтверждения" and a published batch may return to draft (server decides); show the outcome after reload, not before.
- Buyer opening an unpublished/foreign batch gets the "not found or unavailable" screen (404/403 layout). Buyers never see draft-only information, confirmation author, held/transferred masses.
- Buyer request form is outside this phase: no quantity field or "Подать заявку" is rendered.
- Archive: confirmation dialog "Архивировать партию? Она исчезнет из каталога покупателей." Server allows only without active holds.

## 4. Batch statuses (labels, tokens, icons)

A status describes the physical stock state of the batch and nothing else. It is never a forecast: no "ожидается", no plan values, no dotted/italic forecast style. Chips use text plus icon plus token pair; colour is secondary. Pairs reuse checked values from `tokens.md`. Amber warning pair is deliberately not used because it is the forecast pair.

| API status | Label (RU) | Meaning shown in helper text on batch screen | Token pair (fg on bg) | Icon (Material Symbols) |
|---|---|---|---|---|
| `draft` | Черновик | "Не виден покупателям." | neutral: `secondary` `#5B5048` on `secondaryContainer` `#EFE6DE` (6.345 per tokens.md) | `edit_note` |
| `available` | Доступно | "Вся масса свободна." | `status-success-fg` `#1B6B3A` on `status-success-bg` `#DDF3E4` (5.611) | `storefront` |
| `partially_allocated` | Частично распределено | "Часть массы удержана или передана, свободная масса ещё есть." | `onPrimaryContainer` `#3A1800` on `primaryContainer` `#FFDCC2` (12.41) | `pie_chart` |
| `reserved` | Зарезервировано | "Свободной массы нет, есть активный резерв." | `onPrimaryContainer` `#3A1800` on `primaryContainer`, with `border-width-default` 1 `#9A3F00` | `lock` |
| `completed` | Завершено | "Вся масса выбыла." | neutral (as draft) with solid 1 px `outline` | `done_all` |
| `archived` | В архиве | "Скрыто владельцем." | neutral (as draft) | `archive` |

Notes:
- `partially_allocated` and `reserved` share a pair and differ by icon, label and border; this is intended (no colour-only meaning).
- Available (green) shares colours with the "Подтверждено" value kind; they differ by label, icon (`storefront` vs `check_circle`) and placement (status chip in header vs provenance line). Never put both in one chip.
- Label of the chip is the only status text used on all roles; buyers see only Доступно and Частично распределено in the catalog (API behaviour assumed).
- Chip height visual 32 px, it is not interactive (no touch target needed); a status filter option is a separate 48 px control.
- Screen reader reads "Статус: {label}".

## 5. States per screen

Common rules: loading uses a skeleton of the final layout (cards or form) with announcement "Загрузка…"; error uses the envelope `message` verbatim plus small "Код обращения: {request_id}" for 5xx, and the button "Повторить" (not for 403/404); success shows a snackbar and announces it.

| Screen | loading | empty | error | success | 409 | ACTIVE_OBLIGATIONS | 403/404 |
|---|---|---|---|---|---|---|---|
| S03 Catalog | 4-6 card skeletons (list: single column phone, two columns laptop) | owner: text "Партий пока нет. Добавьте первую." + single action "Создать партию". Buyer: text only "Пока нет опубликованных партий." (no action) | panel with message and "Повторить" | list shown; after returning from create, snackbar | n/a for list | n/a | wrong role: panel with "На главную" |
| S03 filtered empty | n/a | "Ничего не найдено. Измените фильтры." + "Сбросить фильтры" (reset is a working action) | | | | | |
| S04 Create/Edit | form skeleton in edit mode | n/a | save error: banner above the form with envelope message, input preserved, "Повторить" | snackbar "Черновик сохранён." and the screen switches to edit mode of the saved batch (or opens S05) | banner "Партия изменилась, обновить данные" with the button "Обновить данные" (reloads the server version; the user's unsaved text is shown below in a collapsible "Ваши изменения" for copy) | banner with the text from the messages table; locked fields become read-only with the field helper text | 403: panel; foreign id 404 panel |
| S04 photo tile | tile progress with percent in accessible name | n/a | tile error with reason and "Повторить"/"Удалить фото" | tile with thumbnail | 409 `IMAGE_LIMIT_REACHED`: "Можно добавить не больше 5 фото." | n/a | |
| S05 Batch | skeleton of header, photo, characteristics | n/a | panel with "Повторить" | content, status chip; snackbar after publish "Партия опубликована." | same banner as S04 with "Обновить данные", then the action stays available | banner on edit/archive attempt | buyer on foreign/unpublished: "Объект не найден или недоступен." + "На главную" |
| S05 publish | button busy | n/a | 422 `PUBLISH_REQUIREMENTS_NOT_MET`: checklist updated from `details.missing` with message "Опубликовать пока нельзя. Выполните пункты ниже." | success text | `VERSION_CONFLICT` as above; `INVALID_TRANSITION`: "Это действие сейчас недоступно: статус партии изменился. Обновите данные." | n/a | |

Photo URLs (signed, short-lived): if a tile fails to load because the link expired, show the placeholder with the "Обновить фото" action; do not show an error banner for it.

## 6. Accessibility (this phase)

- Every field has a persistent visible label above the input (not placeholder-only) and a unit suffix (кг, KGS/кг). Required fields carry the text "Обязательное" (for draft: only Название; for publish the requirement is in the checklist, not as a field mark, to avoid misleading the draft flow).
- Error message is programmatically tied to its field (described-by) and announced assertively on appearance; the field border is `error` colour 2 px plus an icon.
- Minimum touch target 48x48 px, gap >= 8 px: dropdowns, steppers, photo tiles (add/remove padded), chips used as filters, card.
- Focus order (phone and laptop): skip link, navigation, screen title, step indicator, fields in visual order, photo tiles (each tile then its remove button), then the action bar ("Сохранить черновик", "Далее"). Banners and summaries precede the form in reading order; focus moves to the summary only on failed save, then to the first invalid field.
- Sticky bottom action bar on phone must not cover the focused field (scroll into view with padding).
- "Сохранить черновик", "Далее", "Опубликовать", "Архивировать", "Подтвердить характеристики": disabled and `aria-busy` during the request, label "Сохранение…" / "Отправка…", Enter key uses the same lock; Back and step buttons stay usable but the second submit is impossible. The server is idempotent-safe by version check, but the UI does not rely on that.
- Status chips: text plus icon; the "Скоро" marker is plain text, not focusable.
- Photo alt: "Фото партии {название}, {n} из {m}"; the placeholder: "У партии нет фото".

## 7. Responsive table

| Aspect | Phone < 600 (primary) | Tablet 600-839 | Laptop >= 840 (accessibility.md still says 1024; reconcile with Q-T2) |
|---|---|---|---|
| Navigation | bottom bar | rail | sidebar |
| Catalog | 1 column cards, filters in bottom sheet, "Создать партию" extended FAB | 2 columns, filter panel collapsible | 2 columns of cards (list pane + filter row); max content width from tokens |
| Create/edit | 4-step flow, sticky bottom bar ("Сохранить черновик" secondary, "Далее" primary) | one page, sections, bar inline | one page, 2 columns: form left, photos right; actions inline top-right and bottom |
| Batch screen | single column in the order of section 3 | single column, wider photos | 2 columns: photos + status + actions left (sticky), characteristics + balance right |
| Photo tiles | 2 per row | 3 per row | 3 per row |
| Dialogs | full-screen sheet | centered | centered |
| Text scale 200% | single column, no clipped labels, no horizontal scroll at 320 px | | |

## 8. Russian messages (phase 2)

| Key | Text | When shown |
|---|---|---|
| `materials.catalog.title.owner` | Мои партии | S03 title, owner |
| `materials.catalog.title.buyer` | Каталог | S03 title, buyer |
| `materials.catalog.empty.owner` | Партий пока нет. Добавьте первую. | owner list empty |
| `materials.catalog.empty.buyer` | Пока нет опубликованных партий. | buyer list empty |
| `materials.catalog.empty.filtered` | Ничего не найдено. Измените фильтры. | filters give no results |
| `materials.action.create` | Создать партию | catalog (owner), empty state |
| `materials.action.resetFilters` | Сбросить фильтры | filtered empty |
| `common.loading` | Загрузка… | any skeleton |
| `common.retry` | Повторить | network/5xx error |
| `common.error.network` | Не удалось загрузить данные. Проверьте соединение и повторите. | network failure |
| `common.error.server` | Что-то пошло не так. Повторите позже. | 5xx and no envelope message |
| `common.requestId` | Код обращения: {request_id} | 5xx under error text |
| `common.error.forbidden` | У вас нет доступа к этому действию или объекту. | 403 |
| `common.error.notFound` | Объект не найден или недоступен. | 404, buyer on foreign/unpublished batch |
| `common.goHome` | На главную | 403/404 panels |
| `common.saving` | Сохранение… | busy label of save |
| `common.sending` | Отправка… | busy label of publish/confirm/archive |
| `materials.form.title.create` | Новая партия | S04 create |
| `materials.form.title.edit` | Редактирование партии | S04 edit |
| `materials.form.step` | Шаг {n} из {m} | phone step indicator |
| `materials.form.step.hasErrors` | есть ошибки | step marker |
| `materials.form.group.basic` | Основное | step 1 |
| `materials.form.group.mass` | Масса и место | step 2 |
| `materials.form.group.priceDesc` | Цена и описание | step 3 |
| `materials.form.group.photos` | Фото | step 4 |
| `materials.form.field.name` | Название | label |
| `materials.form.field.type` | Тип материала | label |
| `materials.form.field.condition` | Состояние | label |
| `materials.form.field.mass` | Масса, кг | label |
| `materials.form.field.city` | Город | label |
| `materials.form.field.scrap` | Размер обрезков (необязательно) | label |
| `materials.form.field.composition` | Состав (необязательно) | label |
| `materials.form.field.price` | Цена за кг, KGS (необязательно) | label |
| `materials.form.field.description` | Описание (необязательно) | label |
| `common.required` | Обязательное | next to required label |
| `materials.form.hint.mass` | Укажите массу в килограммах, например 12,5. | under mass |
| `materials.form.hint.price` | Оставьте пустым, если цена не определена. | under price |
| `materials.form.hint.composition` | Если состав неизвестен, оставьте поле пустым. Мы не определяем его по фото. | under composition |
| `materials.form.err.nameRequired` | Укажите название партии. | name empty |
| `materials.form.err.number` | Введите число, например 12,5. | non-numeric mass/price |
| `materials.form.err.negative` | Значение не может быть отрицательным. | mass/price < 0 |
| `materials.form.err.massPositive` | Для публикации масса должна быть больше нуля. | only in publish checklist/server 422 |
| `materials.form.err.tooLong` | Слишком длинное значение. Максимум {n} символов. | length exceeded |
| `common.validationSummary` | Проверьте поля формы. | failed save with 422 |
| `materials.form.saveDraft` | Сохранить черновик | secondary action |
| `materials.form.next` | Далее | step button |
| `materials.form.back` | Назад | step button |
| `materials.form.saved` | Черновик сохранён. | save success |
| `materials.form.leave` | Выйти без сохранения? Введённые данные будут потеряны. | leave with changes |
| `materials.photos.saveFirst` | Сначала сохраните черновик, затем добавьте фото. | step 4, unsaved batch |
| `materials.photos.add` | Добавить фото | photo control |
| `materials.photos.limits` | До 5 фото. JPEG, PNG или WebP, не более 10 МБ каждое. | helper in step 4 |
| `materials.photos.uploading` | Загрузка фото… | tile busy |
| `materials.photos.failed` | Не удалось загрузить фото. Повторите или выберите другой файл. | tile error |
| `materials.photos.unsupported` | Файл не подходит: нужен JPEG, PNG или WebP до 10 МБ. | 422 `UNSUPPORTED_IMAGE` |
| `materials.photos.limitReached` | Можно добавить не больше 5 фото. | 409 `IMAGE_LIMIT_REACHED` |
| `materials.photos.remove` | Удалить фото | tile control (accessible name) |
| `materials.photos.none` | Нет фото | catalog placeholder |
| `materials.photos.refresh` | Обновить фото | expired signed link |
| `materials.photos.draftOk` | Фото можно добавить позже, но для публикации нужно хотя бы одно. | step 4 (draft) |
| `materials.card.free` | Свободно: {N} кг | card, available |
| `materials.card.mass` | Масса: {N} кг | draft card |
| `materials.card.price` | {N} KGS/кг | card with price |
| `materials.card.noPrice` | Цена не указана | price null |
| `materials.card.noCity` | Город не указан | draft without city |
| `materials.status.draft` | Черновик | chip |
| `materials.status.available` | Доступно | chip |
| `materials.status.reserved` | Зарезервировано | chip |
| `materials.status.partially_allocated` | Частично распределено | chip |
| `materials.status.completed` | Завершено | chip |
| `materials.status.archived` | В архиве | chip |
| `materials.status.a11y` | Статус: {статус} | screen reader |
| `materials.detail.photos` | Фото | section |
| `materials.detail.characteristics` | Характеристики | section |
| `materials.detail.balance` | Масса, кг | section |
| `materials.detail.balance.total` | Всего | row |
| `materials.detail.balance.free` | Свободно | row |
| `materials.detail.balance.held` | Удержано | row |
| `materials.detail.balance.transferred` | Передано | row |
| `materials.detail.balance.used` | Использовано внутри | row |
| `materials.detail.seller` | Продавец | buyer section |
| `materials.detail.contacts` | Контакты станут доступны после подтверждения заявки. | buyer |
| `materials.detail.unknown` | Не указано | empty optional field |
| `materials.detail.compositionUnknown` | Неизвестно | composition null |
| `materials.confirm.state.confirmed` | Подтверждено, {автор}, {дата} | field provenance |
| `materials.confirm.state.none` | Не подтверждено | not confirmed |
| `materials.confirm.state.stale` | Требует повторного подтверждения | after key change |
| `materials.confirm.action` | Подтвердить характеристики | draft |
| `materials.confirm.summary` | Вы подтверждаете характеристики партии. После подтверждения они используются в подборе и плане. | above confirm |
| `materials.confirm.done` | Характеристики подтверждены. | success |
| `materials.publish.action` | Опубликовать | draft with all requirements |
| `materials.publish.checklistTitle` | Что осталось до публикации | draft checklist |
| `materials.publish.item.photo` | Добавлено хотя бы одно фото | checklist |
| `materials.publish.item.fields` | Указаны тип, состояние и город | checklist |
| `materials.publish.item.mass` | Масса больше нуля | checklist |
| `materials.publish.item.confirm` | Характеристики подтверждены | checklist |
| `materials.publish.blocked` | Опубликовать можно после выполнения всех пунктов. | checklist incomplete |
| `materials.publish.failed` | Опубликовать пока нельзя. Выполните пункты ниже. | 422 `PUBLISH_REQUIREMENTS_NOT_MET` |
| `materials.publish.done` | Партия опубликована. | publish success |
| `materials.archive.action` | Архивировать | owner |
| `materials.archive.confirm` | Архивировать партию? Она исчезнет из каталога покупателей. | dialog |
| `materials.archive.done` | Партия перенесена в архив. | success |
| `materials.action.edit` | Изменить | owner |
| `materials.ai.soon` | Анализ ИИ | inert row title |
| `materials.ai.soonChip` | Скоро | inert chip |
| `common.conflict.version` | Партия изменилась, обновить данные. | 409 `VERSION_CONFLICT` banner text |
| `common.conflict.refresh` | Обновить данные | banner button |
| `materials.conflict.myChanges` | Ваши изменения | collapsible with unsaved input |
| `materials.conflict.transition` | Это действие сейчас недоступно: статус партии изменился. Обновите данные. | 409 `INVALID_TRANSITION` |
| `materials.obligations.edit` | Нельзя изменить тип, состояние, город или массу: по партии есть резервы или переданный объём. | 409 `ACTIVE_OBLIGATIONS` on edit |
| `materials.obligations.mass` | Нельзя уменьшить массу ниже уже зарезервированной, переданной и использованной. | `ACTIVE_OBLIGATIONS` on total_kg decrease |
| `materials.obligations.archive` | Нельзя архивировать: по партии есть активные резервы. | `ACTIVE_OBLIGATIONS` on archive |
| `materials.obligations.fieldLocked` | Нельзя изменить: есть резервы или переданный объём. | helper in locked field |
| `common.rateLimit` | Слишком много запросов. Повторите через минуту. | 429 (e.g. photo upload) |
| `common.session` | Сессия истекла. Войдите снова. | 401 |

Message texts from the server envelope are shown as returned; the keys above are fallbacks and client-side texts. Technical codes (`ACTIVE_OBLIGATIONS`, `VERSION_CONFLICT`) are never shown to the user.

## Open questions

| # | Question | Who answers |
|---|---|---|
| P2-1 | The API has no "описание" field for a batch (MaterialCreateIn has name, type, composition, scrap_size, condition, price, city, total_kg). Add a field, or drop description from this phase? Until answered, the Description field in step 3 is hidden. | orchestrator, backend-engineer |
| P2-2 | Publishing requires a current human confirmation, but AI analysis (S06) is not in this phase. Is a manual "Подтвердить характеристики" on S05 (without analysis_id) the intended path so the batch can be published in phase 2? | orchestrator |
| P2-3 | Can the owner delete a photo or reorder? api.md has upload only (no delete endpoint). Until answered, remove is not shown and the "Удалить фото" key is reserved. | backend-engineer |
| P2-4 | Owner catalog card: does `MaterialOut.balance` expose `available_kg` as a field (card uses it)? And do buyers receive `partially_allocated` only? | backend-engineer |
| P2-5 | Breakpoint for two-column layout: 840 (tokens.md) or 1024 (accessibility.md). | orchestrator, flutter-developer |
| P2-6 | Enum labels for type and condition are assumptions (api.md marks enums as assumed). Confirm the set and Russian wording. | orchestrator, backend-engineer |
