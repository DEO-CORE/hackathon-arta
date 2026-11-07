# UI States and Button Rules

Status: draft, error `code` mapping `[PROVISIONAL]` until CON-01. Display only the envelope `message` (safe) and `request_id` as "Код обращения: ..." in small text on unexpected errors.

## State catalog (applies to every screen in `screens.md`)

| State | Behaviour | Russian text |
|---|---|---|
| loading | Skeleton of final layout; no layout jump; screen reader announces | "Загрузка…" |
| empty | Illustration-free text, reason, one working CTA if any | per screen |
| error (network) | Inline panel, "Повторить" button | "Не удалось загрузить данные. Проверьте соединение и повторите." |
| error (server 5xx) | Same panel, with request id | "Что-то пошло не так. Повторите позже." |
| validation 422 | Message next to each field + summary at top, focus moves to first invalid field | "Проверьте поля формы." |
| success | Toast/snackbar and inline status change; also announced to screen reader | "Сохранено." / "Заявка подана." |
| 401 | Return to S01 | "Сессия истекла. Войдите снова." |
| 403 permission denied | Full-area panel, link to home, no actions | "У вас нет доступа к этому действию или объекту." |
| 404 | Same as 403 layout | "Объект не найден или недоступен." |
| 409 conflict | Banner keeping user input, with refresh action | see below |
| 429 | Banner, retry after delay | "Слишком много запросов. Повторите через минуту." |
| AI pending | Progress with text, no spinner-only | "Анализ выполняется. Можно продолжить заполнение вручную." |
| AI failed | Reason (safe), "Повторить анализ", manual form open | "Анализ не удался. Заполните характеристики вручную или повторите анализ." |
| AI unavailable | Banner, analysis button hidden or disabled with reason, manual open | "Сервис анализа временно недоступен. Каталог и ручной ввод работают." |
| AI stale | Suggestions greyed, confirm disabled | "Данные партии изменились после анализа. Запустите анализ заново." |

## 409 texts (Russian)

| Context | Text |
|---|---|
| Stale version (material/profile/requirement) | "Данные изменились, пока вы их редактировали. Обновите страницу и повторите изменения." |
| Not enough free mass (reserve, request, internal use) | "Недостаточно свободной массы. Доступно: {N} кг. Уменьшите количество или обновите данные." |
| Demand exhausted / exceeded | "Спрос покупателя уже закрыт или меньше запрошенного объёма. Обновите данные." |
| Invalid transition (e.g. confirm already cancelled) | "Это действие сейчас недоступно: статус заявки изменился. Обновите список." |
| Idempotency payload mismatch | "Это действие уже выполнялось с другими данными. Обновите страницу." |
| Stale AI analysis on confirm | "Партия изменилась после анализа. Запустите анализ заново и подтвердите характеристики." |
| Stale plan | "План устарел из-за изменений партии или спроса. Пересчитайте план." |
| Reuse exceeds transferred | "Нельзя подтвердить использование больше переданного объёма ({N} кг)." |
| Active obligations block edit/archive | "Нельзя изменить партию: есть активные резервы." (phase 2 batch-specific variants in `phase-2-materials.md`, keys `materials.obligations.*`) |
| Batch version conflict (phase 2) | "Партия изменилась, обновить данные." with button "Обновить данные" |

`{N}` is taken from the server response when present; if the API does not send it, the sentence is shown without the number (dependency for backend-engineer, Q1).

## 403 texts (Russian)

| Context | Text |
|---|---|
| Generic | "У вас нет доступа к этому действию или объекту." |
| Wrong role for screen | "Этот раздел недоступен для вашей роли." |
| Foreign object (also used for hidden 404) | "Объект не найден или недоступен." |
| Contacts before deal | "Контакты станут доступны после подтверждения заявки." |
| Inactive account | "Учётная запись отключена. Обратитесь к организатору." |

After 403 no retry button is offered (retrying cannot help); offer "На главную".

## Button rules

1. During a request: button disabled, label replaced by "Отправка…" / "Сохранение…", a progress indicator with accessible name; other buttons that trigger the same action are also disabled. Re-enabled on completion.
2. Disabled-until-valid is allowed for confirm/publish only with visible text explaining what is missing; otherwise let the user submit and show 422 errors.
3. No non-working CTA: do not show buttons for features outside MVP (оплата, доставка, чат, kyrgyz language switch, CO2). Do not show an action the role/status cannot perform.
4. Destructive actions (cancel, reject, archive) use a confirmation dialog with explicit consequence text, e.g. "Отменить заявку? Удержанная масса вернётся в свободный остаток."
5. The server is the authority for each action (role, owner, status, version, stock). The UI never assumes success: status changes only after the response.
6. After a 409 the primary action stays available once data is reloaded.
7. Retry after network failure of a mutating request reuses the same idempotency key `[PROVISIONAL]`, so a double tap or retry cannot create a second deal.

## Units and formats

- Mass: "12,500 кг" (3 decimals max, server-provided). Money: "1 250,00 KGS", per-kg "35,00 KGS/кг". Percent: "N %". Always with unit, never bare numbers.
- Placeholders in mockups: "— кг", "— KGS". Unknown value: "Не указано" / "Неизвестно".
- Dates shown in the local time zone with explicit format; stored UTC.

## Open questions

- Does the 409 body include current available kg / current version? (backend-engineer)
- Is the idempotency key client-generated per form open? (backend-engineer)
