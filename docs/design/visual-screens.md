# P0 screen specs, visual refinement (mobile)

Status: draft. Applies `visual-system.md` (tokens, components) to the screens found in `visual-audit-2026-11-07.md`. Behaviour, texts and states from `phase-2-materials.md`, `demo-and-ai.md`, `states.md`, `ai-results.md` stay valid unless a line here says it replaces them. Width reference: 360-412 dp phone, single column, screen margin 16. UI copy Russian. No new functions, no API changes, no invented numbers (examples in brackets are placeholders from demo fixtures). The server enforces every rule; a hidden or disabled button is a convenience.

Layout notation: top to bottom; `[P]` = the single primary action of the screen state; `(x)` = removed or moved.

## S01 Login and registration

Main action: "Войти" (login) or "Зарегистрироваться" (registration), full width, 52 dp, directly under the last field.

Login, top to bottom (top-aligned, scrollable, content starts 32 dp under the demo banner; no vertical centering):
1. Demo banner (shell).
2. Brand block: wordmark "ARTA" `type-headline` bold; under it one line `type-body-md` secondary: "Платформа учёта и повторного использования текстильных остатков". No logo (V-1).
3. Title "Вход" `type-title-xl`, 24 dp below the brand block.
4. Field "Email" (label above, keyboard type email, autofill hint, no autocorrect).
5. Field "Пароль" with the 48 dp toggle "Показать пароль" / "Скрыть пароль".
6. Server or network error panel (only when present) above the button; field errors under fields (texts: `demo-and-ai.md` section 4.2).
7. [P] "Войти" (busy: "Вход…" and ring; Enter obeys the same lock).
8. Text button "Нет аккаунта? Зарегистрироваться" (48 dp, `accent-text`), centered.
9. Demo only: block (white, 1 dp `#E6E8EC` border, radius 16, padding 16) with icon `science`, heading "Демо-вход", the credentials from the fixture as selectable text, and the text button "Заполнить" at the right.

Removed or moved: (demo credentials between title and form), (orange text links), (title larger than the brand).

Registration (same shell; replaces the form; provisional until `docs/api.md` 17.2 is final): title "Регистрация"; fields Email, Пароль (rule hint from the server), "Роль" as two selectable cards (min 72 dp, radio semantics): "Предприятие" and "Покупатель" (a recycler is a buyer with the activity type "Переработчик"); "Название организации"; "Город"; "Тип деятельности" (bottom sheet list; the choice is limited by role as the server defines; `admin` is never offered). [P] "Зарегистрироваться"; text button "Уже есть аккаунт? Войти". After success: return to login with snackbar "Аккаунт создан. Войдите." (a token is not issued by register, `docs/api.md` section 16).

States: loading (button busy only); error (panel: "Неверный email или пароль." / "Слишком много попыток. Повторите через минуту." / "Не удалось войти. Проверьте соединение и повторите."); 409 on register (email taken): field error under Email "Этот email уже зарегистрирован." `[PROVISIONAL, text pending server code]`; success; permission denied n/a. Accessibility: errors cleared when the value changes; no repeated submit; focus to the first invalid field.

## S02 Home

Main action: for `enterprise` "Создать партию"; for `buyer` "Открыть каталог". Placed first under the account row.

Top to bottom:
1. Demo banner.
2. App bar: wordmark "ARTA" left; action "Выйти" (icon 48 dp, name and tooltip).
3. Account row (no card): email `type-label-lg`; below it the role badge (`status-neutral`, icon `business`, label "Предприятие" / "Покупатель" / "Переработчик").
4. [P] "Создать партию" full width 52 dp (enterprise only). Buyer: [P] "Открыть каталог".
5. Section heading "Разделы" `type-title-md`.
6. Navigation card (white, radius 16, `elevation-1`) with 56 dp rows separated by 1 px dividers: icon in a 40 dp circle `#FFF1E6` (icon `#B04A00`), label, chevron. Enterprise rows: "Мои партии", "Организация". Buyer rows: "Каталог", "Организация".
7. Nothing else. No metrics or zero placeholders until the analytics API is integrated (`dashboard.md`).

Removed: (400-800 px of empty space), (email as the biggest text), (plain list with no card).

States: loading (skeleton of the account row and the card); error panel with "Повторить" if the profile call fails; session expired (401): "Сессия истекла. Войдите снова." and the login screen.

## S03 Catalog

Main action: open a batch (card); for the owner, create a batch (FAB). Buyer has no create action.

Top to bottom:
1. Demo banner.
2. App bar: back arrow, title "Мои партии" (buyer: "Каталог").
3. Filter row: horizontally scrollable chips "Все", "Черновик", "Доступно", "Частично распределено", "Зарезервировано", "Завершено", "В архиве" (labels equal to the badges; buyer sees "Все", "Доступно", "Частично распределено" only, as the API returns them). 16 dp left padding, fade at the right edge, chip 40 dp, hit 48 dp, gap 8.
4. List of batch cards (visual-system 5.4), gap 12, margin 16; first card 12 dp under the chips.
5. [P] Owner only: extended FAB "Создать партию" (`#F08331`, label `#17191D`, icon `add`, `elevation-2`, 16 dp from the right and bottom edges plus safe area). List bottom padding 96 dp so that nothing is covered.

Mock of one card (example values from demo fixtures, not real data):

```
[88x88 photo]  Демо-партия: трикотаж
               (Доступно)
               Свободно: 45 кг
               Трикотаж · Хорошее
               Ош · Цена не указана
```

Removed: (peach card and page tints), (saturated placeholder blocks), (price and city as separate equal lines), (FAB over the list), (FAB in the empty state: the empty-state button is the only action).

States: loading (4 card skeletons); empty owner ("Партий пока нет. Добавьте первую." and [P] "Создать партию"); empty buyer (text only); filtered empty ("Ничего не найдено. Измените фильтры." and text button "Сбросить фильтры"); error panel with "Повторить"; 403 wrong role panel with "На главную"; success after create: snackbar "Черновик сохранён."; pull-to-refresh allowed. Accessibility: chips announce "{label}, выбрано"; cards have the composed accessible name; FAB has a 56 dp target.

## S05 Batch detail

Main action: depends on the draft stage; one [P] at a time (sticky bar). Owner and buyer variants; buyer sees only the published fields and "Свободно".

Top to bottom (owner):
1. Demo banner.
2. App bar: back arrow, title "Партия"; action text button "Изменить" (shown only when editing is allowed: draft, available, partially allocated; the server decides and returns 409 otherwise).
3. Gallery: full-width 4:3, radius 16, counter badge "1 из N" at the bottom right (white text on `#17191D` at 72%, 7.5:1 or more by construction, check by tool); more than one photo: swipe plus a strip of 56 dp thumbnails. No photo: panel of the same width, 120 dp high, `#EEF0F3`, icon, "У партии нет фото" and (draft only) text button "Добавить фото".
4. Header: title `type-title-xl` (wraps); status badge; caption `type-body-md` secondary ("Не виден покупателям." / "Скрыто владельцем.") on the next line.
5. Draft only: checklist card "Что осталось до публикации" with a summary line "Выполнено [N] из 4" derived from the four items; rows (icon `check_circle` or `cancel` plus text plus screen-reader text "Выполнено" / "Не выполнено"); an open row shows its hint and a 48 dp text action ("Добавить фото", "Изменить", "Подтвердить характеристики"). Texts: `demo-and-ai.md` section 2.
6. Characteristics card: heading "Характеристики"; provenance badge (Confirmed: "Подтверждено человеком, 07.11.2026", or "Не подтверждено" / "Требует повторного подтверждения"); label/value rows: Тип, Состояние, Город, Размер обрезков, Состав, Цена за кг. Unknown: "Неизвестно" (composition), "Не указано", "Цена не указана".
7. Mass card: heading "Масса, кг"; hero "Свободно" label and the number `type-headline` with the unit ("45 кг"), next to it `type-body-md` "Всего [N] кг" (server fields); rows "Удержано", "Передано", "Использовано внутри" (zeros shown as "0 кг"). Buyer: only "Свободно".
8. AI card "Анализ ИИ": no photo: "Для анализа нужно фото." (no button); has photo, no result: one sentence "ИИ предложит цвет, рисунок и варианты применения. Состав, вес, прочность и безопасность по фото не определяются." and secondary button "Проанализировать фото"; with a result: summary plus text button "Открыть результат"; archived: the section is not rendered (4.5 in the audit).
9. Available or partially allocated: text destructive button "Архивировать партию" at the bottom, separated by 24 dp from the cards.
10. Sticky bottom bar (white, `elevation-2`, 16 dp padding plus safe area) with the one [P]:
   - draft, checklist items 1-3 complete, item 4 open: [P] "Подтвердить характеристики" (summary text above the button in the card, `materials.confirm.summary`);
   - draft, all complete: [P] "Опубликовать";
   - otherwise: no bar; the open rows carry the actions.

Removed: ("Подтвердить характеристики" above the checklist), (full-width "Изменить"), (the "Фото: 1" label and the square thumbnail), (bold "label: value" lines), (empty "Анализ ИИ" heading).

### Publish dialog (replaces the direct publish in `phase-2-materials.md`; needs confirmation V-7)

- Title: "Опубликовать партию?"
- Body: "Партия появится в каталоге покупателей. Контакты видны только участникам сделки."
- Buttons: "Отмена" (initial focus, secondary), "Опубликовать" (primary). Busy: "Отправка…".
- Outcomes: success: dialog closes, snackbar "Партия опубликована.", badge becomes "Доступно"; 422 `PUBLISH_REQUIREMENTS_NOT_MET`: dialog closes, the checklist is updated from the server list and the banner "Опубликовать пока нельзя. Выполните пункты ниже."; 409: banner "Партия изменилась, обновить данные." with "Обновить данные"; 429: "Слишком много запросов. Повторите через минуту."

### Archive dialog

- Title: "Архивировать партию?"
- Body: "Она исчезнет из каталога покупателей. Партию со свободной массой и без активных резервов можно архивировать." Add the sentence "Вернуть партию из архива в приложении нельзя." only if V-4 confirms there is no unarchive.
- Buttons: "Отмена" (initial focus), "Архивировать" (destructive filled). Busy: "Отправка…".
- Outcomes: success: snackbar "Партия перенесена в архив." and return to the catalog; 409 active holds: dialog closes, banner "Нельзя архивировать: по партии есть активные резервы."; `INVALID_TRANSITION`: banner "Это действие сейчас недоступно: статус партии изменился. Обновите данные."

States of S05: loading (skeleton: gallery block, title lines, two cards); error panel with "Повторить"; buyer on a foreign or unpublished batch: "Объект не найден или недоступен." and "На главную"; 409 banner; success snackbars; AI states: see S06.

## S04 Create and edit

Main action: "Сохранить черновик" (saves the whole form). Publishing is on S05, never in this form.

Single scrolling page with sections (V-3), top to bottom:
1. Demo banner.
2. App bar: close/back arrow with the guard "Выйти без сохранения? Введённые данные будут потеряны." when there are unsaved changes; title "Новая партия" (edit: "Редактирование партии").
3. Error summary (only after a failed save): "Проверьте поля формы."; focus goes to the first invalid field.
4. Section "Основное" (card, 16 padding): "Название" (tag "Обязательное"), "Тип материала" (bottom sheet), "Состояние" (bottom sheet).
5. Section "Масса и место": "Масса" with suffix "кг" and helper "Укажите массу в килограммах, например 12,5."; "Город"; "Размер обрезков"; "Состав" with helper "Если состав неизвестен, оставьте поле пустым. Мы не определяем его по фото."
6. Section "Цена": "Цена за кг" with suffix "KGS/кг" and helper "Оставьте пустым, если цена не определена."
7. Section "Фото партии": photo component (visual-system 5.6); before the first save: "Сначала сохраните черновик, затем добавьте фото."; demo note "Демо: фото сохраняется только на этом устройстве." under the grid.
8. Sticky bottom bar: [P] "Сохранить черновик" full width, 52 dp (single action; replaces the button at the end of the scroll content). Content bottom padding = bar height + 16.

Removed: ("(необязательно)" in labels: optional fields have no tag; the section "Цена" and the fields marked only by "Обязательное" where needed), (inline save button at the end of the content), (orange outlined "Добавить фото").

Field texts, validation: `demo-and-ai.md` section 4.1. States: edit loading (form skeleton); save busy ("Сохранение…"); error (summary plus field errors, input kept); 409 version banner with "Обновить данные" and the collapsible "Ваши изменения"; `ACTIVE_OBLIGATIONS`: locked fields read-only with the helper "Нельзя изменить: есть резервы или переданный объём."; success: snackbar "Черновик сохранён." and the screen opens S05.

## S06 AI analysis with confirmation

Main action: "Подтвердить характеристики" (human action). AI never confirms.

Top to bottom:
1. Demo banner.
2. App bar: back arrow, title "Анализ ИИ".
3. Notice plate (not dismissible): API mode `status-info-suggested` pair, dashed border, icon `auto_awesome`, "ИИ-результат, требует проверки"; demo mode `status-neutral` with stripe, icon `science`, "Симуляция" and "Это пример результата, а не ответ реального сервиса ИИ."
4. Standing notice (plate `#EEF0F3`, icon `info`): "ИИ не определяет состав, вес, прочность и безопасность материала."
5. Photo strip: 72 dp thumbnails of the analysed photos.
6. State area (one of):
   - pending/running: skeleton lines, indeterminate linear bar, "Анализ выполняется…" (pending: "Анализ поставлен в очередь…"); text button "Закрыть" (the analysis continues);
   - succeeded: sections below;
   - failed: error panel "Анализ не удался." plus the server message or "Не удалось выполнить анализ. Повторите попытку."; 5xx adds "Код обращения: {request_id}"; secondary button "Повторить"; line "Вы можете подтвердить характеристики вручную.";
   - interrupted: "Анализ прерван. Запустите заново." with "Запустить заново";
   - unavailable: neutral plate "Анализ ИИ сейчас недоступен. Каталог и ручной ввод работают."; no analysis button;
   - stale: warning banner "Данные партии изменились. Запустите анализ заново." with "Запустить заново"; the old result is not confirmable.
7. Section "Визуальные признаки" (card per feature: цвет, рисунок, фактура): label, value, badge "Предложение ИИ", suitability or confidence in words ("Уверенность: средняя", icon plus text, never a number or a colour-only bar), line "Почему: {причина}". Unknown: "Неизвестно".
8. Section "Варианты применения": a card per option: name, suitability in words, "Почему: {причина}", badge "Предложение ИИ".
9. Composition row, always: "Состав: Неизвестно. По фото не определяется."
10. Section "Ваша проверка": for each reviewed field two lines: "Предложение ИИ: {значение}" (suggested style, read-only) and the input "Ваше значение" (empty by default, so a suggestion is never confirmed by default); text button "Принять предложение" copies the value into the input and the line then reads "Указано вами". Which fields are stored is open (V-8).
11. Sticky bar: [P] "Подтвердить характеристики" (busy "Отправка…"); after success the section shows the Confirmed badge with author and date and the snackbar "Характеристики подтверждены."

Removed: (any "подтверждено" or green style on AI content before the button), (numeric confidence), (a second analysis start button while running).

States: loading, empty (no photo: the screen is not reachable; the batch screen shows "Для анализа нужно фото."), error, 409 version (stale), 403/404, 429 ("Слишком много запросов. Повторите через минуту."), live-region announcements for pending, completed and failed. Focus after a failure goes to the error panel heading.

## Open questions

| # | Question | Who answers |
|---|---|---|
| V-7 | Add a confirmation dialog before publishing? (Earlier specs publish directly.) | customer |
| V-8 | What does the API store when the human edits an AI feature (colour, pattern, texture)? The current confirm uses batch fields only. | backend-engineer, ai-engineer |
| V-9 | Register field set and role labels (provisional); email-taken code | backend-engineer |
| V-10 | Confirm the update of `phase-2-materials.md` section 7 (no bottom navigation on the mobile client) | orchestrator |
| V-11 | Contrast of the white-on-scrim counter badge on photos: verify with a tool over real photos | qa-engineer |
