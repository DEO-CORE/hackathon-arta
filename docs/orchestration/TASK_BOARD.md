# ARTA Task Board

States: `todo`, `in_progress`, `blocked`, `done`.
Priority: P0 (MVP and pitch critical), P1 (UX and extra tests), P2 (nonessential).

**Status 2026-11-07:** execution plan approved by the user (APP-01). Wave 0 (contracts and specs) is complete: ARC-01, CON-01…CON-04, QA-01, PIT-01 are `done`, each checked against its file. Mobile Phase 1 (FE-01) is `done` for the auth shell, verified 2026-11-07. Mobile Phase 2 (materials) is accepted on the client side (2026-11-07): format, analyze and 85 tests verified by orchestrator. Live API still pending BE-03.

**Phase 2.1 — material lifecycle (in progress, 2026-11-07):**
- LC-01 backend-engineer: lifecycle contract (publish, archive, errors) in `docs/api.md` section 19 — in progress.
- LC-02 flutter-developer: publish and archive on the client, validation, errors 403/404/409/429, optimistic concurrency, photo idempotency — in progress.
- LC-03 qa-engineer: lifecycle test plan `docs/qa/lifecycle-test-plan.md` — in progress; tests after LC-02.

**Demo recovery and E2E (in progress, 2026-11-07), from `docs/qa/device-e2e-2026-11-07.md`:**
- DEV-04 demo workflow (photo, confirm, publish, persistence, reset): flutter-developer — in progress.
- DEV-01, DEV-02, DEV-03, DEV-05 UI defects: flutter-developer, ux-designer spec `docs/design/demo-and-ai.md` — in progress.
- Demo AI fixture `docs/fixtures/demo-analysis.json` and provider-independent contract: ai-engineer — in progress.
- BE-01, BE-02, BE-03 backend implementation: backend-engineer — in progress (blocked if PostgreSQL is unavailable).
- Device E2E plan v2 `docs/qa/device-e2e-plan-v2.md`: qa-engineer — in progress; device re-run after implementation.

**Phase 3 — AI (contract, in progress 2026-11-07):**
- AI-C1 ai-engineer: request/response, states, retry, demo isolation in `docs/ai-schema.md` — in progress. Mobile screen and confirmation flow follow after AI-C1 and LC-02. Backend tasks BE-01…BE-09 are still `todo`; the mobile client uses replaceable repositories until they exist.

Acceptance criteria are checked by the orchestrator against real output. "Verified" means a command was run and its output was read.

## 1. Orchestration and architecture

| ID | Pri | Owner | State | Task | Depends on | Acceptance criteria |
|---|---|---|---|---|---|---|
| ARC-01 | P0 | orchestrator | done | Record architecture decisions: stack, solver choice, optimization module location, AI adapter location, auth approach | — | `docs/decisions.md` exists with one entry per decision; solver choice is one of OR-Tools or SciPy, not both |
| ARC-02 | P0 | user | todo | Rename `Claude.md` to `CLAUDE.md` in the file system (case change) | — | `ls` shows `CLAUDE.md`; git (once initialised) tracks the correct name |
| ARC-03 | P0 | user | todo | Record hackathon start time and confirm the 48-hour deadline | — | `START` value in `ORCHESTRATOR.md` section 4 is filled in |
| ARC-04 | P0 | orchestrator | todo | Create repository skeleton folders from `CLAUDE.md` §12 that are needed by the first task only | ARC-01 | Only the folders needed now exist; no empty layers |

## 2. Contracts

| ID | Pri | Owner | State | Task | Depends on | Acceptance criteria |
|---|---|---|---|---|---|---|
| CON-01 | P0 | backend-engineer | done (orchestrator approved v1 as the basis for mobile Phase 1, 2026-11-07; open questions listed in api.md) | Write `docs/api.md` v1: all routes in `CLAUDE.md` §9 with request/response DTOs, status codes, error envelope, pagination, idempotency-key rules | ARC-01 | Every route in §9 listed; each DTO has field types; decimals are strings; orchestrator reviews and approves |
| CON-02 | P0 | ai-engineer | done (docs/ai-schema.md checked: no composition/weight/strength/safety fields; extra="forbid") | Define AI analysis output schema (visual features, reuse options, status, schema version) as a Pydantic model spec | ARC-01 | Schema matches `CLAUDE.md` §6; unknown composition is `null`/`unknown`; no composition, weight or safety fields are populated by the model |
| CON-03 | P0 | optimization-engineer | done (docs/optimization-contract.md checked: fixed fee not modelled, random_seed null) | Define the compatibility function signature and the matching/optimizer input and output schema | ARC-01, CON-01 | One function used by both matching and optimizer; result includes status (`optimal`/`feasible`/`infeasible`/`timeout`/`error`/`heuristic`), remainder, reasons |
| CON-04 | P0 | ux-designer | done (docs/design/ checked; provisional until api.md is frozen; brand colours pending tokens update) | Design specs for MVP screens and all UI states (`docs/design/`) | ARC-01 (provisional until CON-01) | Every MVP screen in `CLAUDE.md` §14 has loading/empty/error/success/409/permission states; AI confirmed-vs-suggested distinction defined |

## 3. Backend

| ID | Pri | Owner | State | Task | Depends on | Acceptance criteria |
|---|---|---|---|---|---|---|
| BE-01 | P0 | backend-engineer | todo | FastAPI skeleton, config from environment (no defaults for secrets), SQLAlchemy session, Alembic baseline | CON-01 | `alembic upgrade head` runs on an empty PostgreSQL DB; `/health` returns without secrets; `pytest` and `ruff` run |
| BE-02 | P0 | backend-engineer | todo | Auth: register, login, JWT (algorithm allowlist, exp), roles, organization checks | BE-01 | Admin role cannot be self-assigned; login returns token; protected route returns 401 without token; cross-org access returns 403/404 in tests |
| BE-03 | P0 | backend-engineer | todo | Organizations, materials CRUD, version field, publication rules | BE-02 | Publish rejected without type/mass/state/city/confirmation; PATCH with stale version returns 409 |
| BE-04 | P0 | backend-engineer | todo | Image metadata and signed-URL upload path (Supabase Storage, private bucket) | BE-03 | Only JPEG/PNG/WebP accepted by signature; size limits enforced; only object keys stored; no permanent URLs in DB |
| BE-05 | P0 | backend-engineer | todo | Buyer requirements CRUD (own only) | BE-02 | Buyer cannot read or edit other organizations' requirements; `min_kg ≤ max_kg` enforced |
| BE-06 | P0 | backend-engineer | todo | Reservations: create (idempotent), confirm, cancel, transfer, complete; row locking per `CLAUDE.md` §5 | BE-03, BE-05 | Race test (QA-03) passes on PostgreSQL; repeated action creates no second transaction |
| BE-07 | P0 | backend-engineer | todo | Internal use operation with impact record | BE-06 | Balance invariant holds after each operation; no double counting |
| BE-08 | P0 | backend-engineer | todo | Analytics summary with separate registered / distributed / confirmed-reuse / revenue / forecast fields | BE-06, BE-07 | Forecast does not increase revenue; empty dataset returns zeros; unit tests cover the definitions in `CLAUDE.md` §10 |
| BE-09 | P0 | backend-engineer | todo | Synthetic demo fixtures and an idempotent seed command (only after the command exists, named in README) | BE-06, OPT-02 | Fixtures labelled synthetic; seed run twice leaves the same data; command recorded in README only after it runs |

## 4. AI

| ID | Pri | Owner | State | Task | Depends on | Acceptance criteria |
|---|---|---|---|---|---|---|
| AI-01 | P0 | ai-engineer | todo | Vision adapter interface, mock provider, prompt, Pydantic validation | CON-02, BE-01 | Mock-based tests cover valid JSON, invalid JSON, schema violation, timeout; invalid output stored as `failed` |
| AI-02 | P0 | ai-engineer | todo | Analysis job lifecycle: job saved before run, background task, `interrupted` on restart, bounded concurrency | AI-01, BE-03 | `POST /ai/analyze` returns 202 with analysis_id; GET shows state; restart test marks stale jobs `interrupted` |
| AI-03 | P0 | ai-engineer | todo | Live provider adapter | AI-02, **user: API key and provider choice (BLK-02)** | One real analysis run on a synthetic photo, output reviewed by a human; result reported as live, not mock |
| AI-04 | P0 | ai-engineer | todo | Confirmation rule: AI result never writes confirmed attributes; `input_version` check on confirm | AI-02, BE-03 | Test: stale analysis cannot confirm a changed material; no code path auto-confirms |

## 5. Optimization

| ID | Pri | Owner | State | Task | Depends on | Acceptance criteria |
|---|---|---|---|---|---|---|
| OPT-01 | P0 | optimization-engineer | todo | Compatibility function and matching with versioned score rules (0–100) and stable ordering | CON-03, BE-03, BE-05 | Hard filters tested; unknown critical attributes never match; same function imported by optimizer (checked by test) |
| OPT-02 | P0 | optimization-engineer | todo | Allocation optimizer (chosen solver), remainder, status, input snapshot, fallback and baseline | OPT-01 | Known small optimum test passes; repeat runs identical on demo fixture; `feasible` never labelled optimal; baseline feasible on same inputs |
| OPT-03 | P0 | optimization-engineer | todo | Post-rounding checks: balance, demand, compatibility | OPT-02 | Test with rounding edge case fails before the check and passes after it |

## 6. Flutter

| ID | Pri | Owner | State | Task | Depends on | Acceptance criteria |
|---|---|---|---|---|---|---|
| FE-01 | P0 | flutter-developer | done for Phase 1 shell (2026-11-07): format, analyze and test re-run by orchestrator on Flutter 3.47.5 (9 tests passed). Not yet verified against live API (BE-02 todo) | App shell, theme from design tokens, API client with base URL from `String.fromEnvironment`, auth screens | CON-01, CON-04, BE-02 | `dart format` check, `flutter analyze`, `flutter test` run and passing; login error shown from error envelope |
| FE-02 | P0 | flutter-developer | done for client side (2026-11-07): format, analyze, 85 tests pass; verified against fakes only, live API pending BE-03 | Catalog list, material create/edit, photo upload UI | FE-01, BE-03, BE-04 | Widget tests for form and 409 display; no HTTP calls from widgets; upload shows progress and error states |
| FE-03 | P0 | flutter-developer | todo | AI analysis screen with confirmation and visible suggested-vs-confirmed split | FE-02, AI-02, AI-04 | Confirm button disabled while request in flight; AI-unavailable state keeps manual entry usable |
| FE-04 | P0 | flutter-developer | todo | Matching and allocation plan screens, with explanations and remainder | FE-03, OPT-02 | Plan shows forecast labels and remainder; status `feasible` displayed as such |
| FE-05 | P0 | flutter-developer | todo | Reservations/transactions and dashboard analytics screens | FE-04, BE-08 | Transfer and confirmed reuse shown as separate states; forecast labelled |
| FE-06 | P1 | flutter-developer | todo | Responsive layout pass and accessibility fixes from UX spec | FE-05, CON-04 | Phone and laptop widths checked; touch targets and focus order per spec |

## 7. QA

| ID | Pri | Owner | State | Task | Depends on | Acceptance criteria |
|---|---|---|---|---|---|---|
| QA-01 | P0 | qa-engineer | done (docs/qa/ checked: 4 files, all cases in plan status) | Test plan and authorization matrix in `docs/qa/` | CON-01 | Covers all roles and nested IDs in `CLAUDE.md` §4 |
| QA-02 | P0 | qa-engineer | todo | API contract check against `docs/api.md` | BE-01, CON-01 | Status codes and error envelope verified by running tests |
| QA-03 | P0 | qa-engineer | todo | Race test: two sessions reserving above available stock on PostgreSQL | BE-06 | One success, one 409, no negative stock; test output recorded |
| QA-04 | P0 | qa-engineer | todo | End-to-end run of demo path (`docs/demo.md`) on fresh migrated DB | FE-05, BE-09, AI-03 or fallback | Each step run; failures logged with severity; no manual data edits |
| QA-05 | P1 | qa-engineer | todo | Additional invariant and AI-error tests | BE-08, AI-04, OPT-03 | Tests run and passing; findings in `docs/qa/issues.md` |

## 8. Pitch

| ID | Pri | Owner | State | Task | Depends on | Acceptance criteria |
|---|---|---|---|---|---|---|
| PIT-01 | P0 | business-analyst | done (docs/pitch/business/ checked; market data in market-data.md and market-data-2.md; 29 assumptions) | Problem, segments, competitors, model, unit economics, assumptions register | **user: any real facts to supply (USR-03)** | Every number labelled verified/assumption/to-validate; register complete |
| PIT-02 | P0 | impact-analyst | todo | KPIs, measurement framework, baseline, evidence plan | PIT-01 (register IDs) | No environmental figure without method and source |
| PIT-03 | P0 | pitch-strategist | todo | 3-minute and 5-minute pitch drafts, demo script, claims check | PIT-01, PIT-02, QA-04 (demo result) | Every claim traceable in `claims-check.md`; demo script uses only steps that were run |
| PIT-04 | P0 | jury-simulator | todo | Scorecard with ranges, AI challenge, assumption audit, priority fixes | PIT-03 | Scores labelled as estimates; top five fixes actionable |
| PIT-05 | P0 | pitch-strategist | todo | Revision after jury review and Q&A rehearsal | PIT-04 | Rehearsal log in `docs/pitch/jury/` |
| PIT-06 | P1 | jury-simulator | todo | Timed Q&A rehearsal rounds | PIT-05 | Each round recorded with question, answer, rating |

## 9. Final delivery

| ID | Pri | Owner | State | Task | Depends on | Acceptance criteria |
|---|---|---|---|---|---|---|
| FIN-01 | P0 | orchestrator | todo | Gate 4 and Gate 5 review | QA-04, PIT-04 | `QUALITY_GATES.md` updated with evidence |
| FIN-02 | P0 | qa-engineer | todo | Final rehearsal of demo, with fallback run | FIN-01 | Demo run time and result recorded |
| FIN-03 | P0 | orchestrator | todo | Final README: only verified commands, env names, known limitations, AI mode, economic assumption source | FIN-02 | Every command in README was run; no nonexistent scripts |

## 10. Blockers requiring the user

| ID | Blocks | Question for the user | State |
|---|---|---|---|
| BLK-01 | ARC-02, ARC-03 | Rename `Claude.md` to `CLAUDE.md`? Provide the hackathon start time. | blocked |
| BLK-02 | AI-03 | Which vision provider and model to use, and the API key (kept in a local `.env`, never committed)? | blocked |
| BLK-03 | BE-04 | Supabase project and private bucket: are they available, and who creates them? | blocked |
| BLK-04 | OPT-02 | Approve the solver choice (proposed: SciPy `milp`), or name a different one. | blocked |
| USR-03 | PIT-01 | Any real facts for the pitch: pilot partners, interviews, volumes, prices. Without them, all figures stay labelled as assumptions. | blocked |
| APP-01 | all implementation | Approve the execution plan in `DEPENDENCIES.md` section 5. | blocked |

## 11. Risk register

| ID | Risk | Likelihood | Impact | Mitigation | Owner |
|---|---|---|---|---|---|
| R-01 | Live vision API not available in time | medium | high | Mock demo mode clearly labelled; fallback fixture; manual entry always works | ai-engineer |
| R-02 | Double reservation under concurrency | medium | high | Row locking; race test QA-03 gates the demo | backend-engineer, qa-engineer |
| R-03 | Solver scope grows (min-lot, costs) | high | medium | Start with per-kg costs; min-lot via one binary; cut P1 first | optimization-engineer |
| R-04 | Pitch claims outrun the MVP | high | high | Claims check; every claim traced to a run feature | pitch-strategist |
| R-05 | No real market evidence | high | high | Label assumptions; state the validation plan honestly | business-analyst |
| R-06 | Flutter and backend diverge on DTOs | medium | medium | `docs/api.md` frozen at CON-01; contract checks QA-02 | orchestrator |
| R-07 | Scope creep into out-of-scope features | medium | high | MVP scope in `CLAUDE.md` §2; P2 blocked until P0 done | orchestrator |
