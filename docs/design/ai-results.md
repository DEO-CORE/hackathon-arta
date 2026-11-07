# AI Results and Value Provenance

Status: draft, `[PROVISIONAL]` until CON-02 (AI schema) and CON-03 (plan schema).

## Five value kinds

Each value on screen belongs to exactly one kind. Kind is shown by label text plus icon and style; colour is never the only signal (tokens in `tokens.md`).

| Kind | Meaning | Label (RU) | Style token | Icon |
|---|---|---|---|---|
| Suggested | AI proposal, not accepted | "Предложение ИИ" | `value-suggested-*`: dashed border, tinted background | sparkle outline |
| Confirmed | Accepted by a named human | "Подтверждено" + "{ФИО/организация}, {дата}" | `value-confirmed-*`: solid border, check | filled check |
| Forecast | Calculated expectation | "Ожидается" (prefix on number), caption "Прогноз, не факт" | `value-forecast-*`: dotted underline, italic caption | trend/clock |
| Fact | Registered/transferred/confirmed actual | "Факт" caption where mixed with forecasts; otherwise section title | `value-fact-*`: solid, regular weight | filled dot |
| Demo | Synthetic seed/mock data | "Демо" badge on card/value | `value-demo-*`: diagonal-stripe badge | flask |

Demo can combine with others (a demo fact is "Факт · Демо"). If an AI result comes from mock or fallback, the banner says "Демо-режим: результат получен не от реального сервиса ИИ" `[PROVISIONAL: needs mode field, Q3]`. Mock is never shown as live.

## Mandatory notice (S06, always visible, not dismissible)

"ИИ оценивает только внешний вид по фото: цвет, рисунок, предполагаемую фактуру. Он не определяет состав, вес, прочность и безопасность материала. Эти данные указывает и подтверждает человек."

## S06 layout

1. Notice (above).
2. Block A "Предложения ИИ" (read-only):
   - Visual features: цвет, рисунок, фактура. Unknown: "Не определено".
   - Reuse options: name, suitability (e.g. Высокая / Средняя / Низкая as text chip + icon), reason line "Почему: …" for every item. Max items as per schema.
   - Per-suggestion action "Принять в форму" copies the value into Block B as an editable draft (still unconfirmed) and marks it "Взято из предложения ИИ".
3. Block B "Характеристики партии" (editable form, the human's data): type, condition, mass, composition (optional, default "Неизвестно"), size, etc. Pre-filled only from user's own entries; AI values enter only through "Принять в форму".
4. Confirm bar: checkbox-free single action "Подтвердить характеристики" with summary text "Вы подтверждаете характеристики партии. После подтверждения они используются в подборе и плане."
5. After confirmation: Block B shows each field as Confirmed with author and time; Block A remains as historical "Предложения ИИ (не подтверждены)". Raw AI JSON is never shown or used by matching.

## Rules

- AI never fills Block B automatically and never confirms. Matching and plan use only confirmed characteristics.
- Editing any input (photo, mass, type, condition…) after confirmation: confirmed marks become "Требует повторного подтверждения"; matching/plan show "Подбор/план основан на устаревших данных" and offer re-analysis/re-confirm. Server rejects stale confirmation (409 text in `states.md`).
- Analysis states: pending/running ("Анализ выполняется"), succeeded, failed, interrupted ("Анализ прерван. Запустите заново."), unavailable. Each leaves the manual form usable.
- Invalid AI output is shown as failed, with no partial suggestions.
- Reasons are shown for every suggestion; if the schema lacks a reason, the suggestion is not shown (dependency, Q3).
- Plan and matching pages repeat kind labels: score "расчёт по правилам v…" is a rule result, not AI; plan values "Ожидается".
- Suggestions never contain a percentage "вероятность продажи" or CO2 value.

## Open questions

- Fields in the analysis result: suitability scale, number of reuse options, `mode` field (ai-engineer).
- Who is the displayed confirmer: user name or organization? (backend-engineer)
- Which confirmed fields exactly are "key characteristics" required for publish? (backend-engineer, orchestrator)
