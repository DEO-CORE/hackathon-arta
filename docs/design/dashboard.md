# Dashboard Metrics

Status: draft, `[PROVISIONAL]` until BE-08 and `docs/api.md`. Definitions follow CLAUDE.md §10. The client displays server values and never sums, derives or estimates them. No number below is a real value; mockups use `— кг` / `— KGS`.

## Enterprise metrics

| Order | Label (RU) | Kind | Definition | Unit |
|---|---|---|---|---|
| 1 | "Зарегистрировано" | Fact | Registered mass, no repeat summing | кг |
| 2 | "Свободный остаток" | Fact | Available, unallocated mass | кг |
| 3 | "Распределено" | Fact | Active reservations + transferred, no double count | кг |
| 4 | "Подтверждённое использование" | Fact | Only separate reuse confirmations | кг |
| 5 | "Выручка по завершённым сделкам" | Fact | Sum of completed sales; excludes transfers in progress, reservations, internal savings. Caption: "Сумма сделок на платформе, не банковская сверка." | KGS |
| 6 | "Эффективность распределения" | Fact (derived by server) | distributed / registered × 100; 0 if no base | % |
| 7 | "Ожидаемая чистая ценность плана" | Forecast | From the latest saved plan; prefix "Ожидается"; caption with plan date and status | KGS |
| 8 | "Прогнозный остаток плана" | Forecast | Remainder of that plan, separate from card 2 | кг |

Layout: facts (1-6) in group "Факты"; forecasts (7-8) in a visually separate group "Прогноз (ожидается)" with `value-forecast` style. Forecast never appears in the Revenue card and is never added to it. "Передано" and "Подтверждённое использование" are separate cards (transfer is not use). Phone: single column in that order; laptop: 3-column grid.

## Buyer metrics

| Label | Kind | Definition |
|---|---|---|
| "Активные заявки" | Fact | Count of pending+confirmed requests |
| "Получено" | Fact | Mass transferred to buyer and received, кг |
| "Подтверждённое использование" | Fact | Buyer-confirmed reuse, кг |
| "Осталось спроса" | Fact | Sum of remaining demand of active requirements, кг |

No buyer revenue or forecast.

## Rules

- CO2 / environmental card: not shown (no methodology). If requested, display nothing rather than a placeholder CTA.
- Demo data: dataset-level banner "Демо-данные" if the server flags it, plus badge on affected cards (Q6).
- Empty dataset: zeros with "0 кг" / "0,00 KGS" and text "Данных пока нет. Добавьте первую партию." (not blank, not an error).
- No latest plan: forecast group shows "План не построен." with a working link to the plan flow (only for enterprise with eligible materials).
- Error in one card does not break others; each card has its own loading/error with retry.
- Each card has a "?" info text with the definition above (screen-reader accessible).
- No trend arrows, percentages of change, or comparisons to market without data.

## Open questions

- Does the analytics response include forecast fields from the last plan or must the client fetch the plan? (backend-engineer)
- Is "Эффективность распределения" shown as a metric on MVP, or only the underlying numbers? (orchestrator)
- Buyer analytics fields available? (backend-engineer)
