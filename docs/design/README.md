# ARTA Design Specs (CON-04)

Status: **draft, provisional**. `docs/api.md` (CON-01) does not exist yet, so every field name, status value and error code below is a design assumption. Dependent items are marked `[PROVISIONAL]` and must be re-checked when CON-01 is approved. UI copy is Russian; headings and identifiers are English. No code, no endpoints are proposed here.

## Index

| File | Content |
|---|---|
| `journeys.md` | Journeys for enterprise, buyer, recycler mapped to the MVP path |
| `screens.md` | Screen map, navigation, per-screen goal/role/layout/actions |
| `states.md` | Shared UI states (loading, empty, error, success, 409, 403, AI pending/failed/unavailable), Russian texts, button rules |
| `ai-results.md` | AI suggested vs human-confirmed vs forecast vs fact vs demo distinction |
| `dashboard.md` | Metric definitions and labels |
| `tokens.md` | Design token names (no brand binding) |
| `accessibility.md` | Contrast, touch targets, focus order, responsive rules |
| `phase-2-materials.md` | Phase 2 mobile: batch create flow, catalog card, batch screen, statuses, states, messages (S03-S05) |

## Screen map (MVP)

| ID | Screen | Roles |
|---|---|---|
| S01 | Login / Registration | public |
| S02 | Dashboard | enterprise, buyer |
| S03 | Catalog | enterprise (own), buyer (published) |
| S04 | Material create/edit (with photo upload) | enterprise |
| S05 | Material card | enterprise, buyer (published fields only) |
| S06 | AI analysis and confirmation | enterprise |
| S07 | Matching results | enterprise |
| S08 | Allocation plan | enterprise |
| S09 | Requests and transactions | enterprise, buyer |
| S10 | Buyer requirements (list/edit) | buyer, recycler |
| S11 | Profile | enterprise, buyer |

Analytics lives on S02 (see `dashboard.md`). No admin, payments, delivery routing, chat, or Kyrgyz UI (CLAUDE.md §2).

## Global rules (summary)

1. Server enforces every rule; hiding a button is only a convenience.
2. A button that cannot work in the current state is not shown; if the user needs to understand why, show explanatory text instead of a dead CTA.
3. Submit buttons disable and show progress while the request runs; one request per action.
4. Units are always written: `кг`, `KGS`. Money and mass are shown as decimal strings from the server, not recomputed on the client.
5. Forecast, suggestion, confirmed fact and demo data are visually and textually distinct (`ai-results.md`).
6. No invented numbers, prices, demand or CO2 in mockups: use `—` or `[пример]` placeholders.

## Open questions

| # | Question | Who answers |
|---|---|---|
| Q1 | Final DTO field names, status enums, error `code` values (CON-01) | backend-engineer |
| Q2 | Does the API expose per-reservation reasons (cancel reason) and `request_id` in errors for display? | backend-engineer |
| Q3 | Does the AI result carry per-suggestion `reason` text and a `mode` field (live/mock/fallback)? | ai-engineer |
| Q4 | Which buyer fields are "published" (visible to buyers) and when contacts become visible | backend-engineer, orchestrator |
| Q5 | Plan result fields: status values, baseline, remainder, assumption origins (CON-03) | optimization-engineer |
| Q6 | Does analytics return a demo flag per value or per dataset? | backend-engineer |
| Q7 | Brand colours, logo, fonts (tokens are names only) | user |
| Q8 | Token lifetime 60 min (D-06): session-expiry UX confirmed? | backend-engineer |
