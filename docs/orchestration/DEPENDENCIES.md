# ARTA Dependencies, Ownership and Execution Plan

## 1. Dependency graph

Arrows read "must be done before". Task IDs are defined in `TASK_BOARD.md`.

```
ARC-01 (decisions) ──┬─> CON-01 (API contract) ──┬─> BE-01 (skeleton) ─> BE-02 (auth) ─> BE-03 (materials) ─┬─> BE-04 (images)
                     │                           │                                                         ├─> BE-05 (requirements)
                     │                           │                                                         │
                     │                           ├─> CON-04 (UX specs) ─────────────────────────┐          │
                     │                           ├─> QA-01 (test plan), QA-02 (contract check)  │          │
                     │                           │                                              │          │
                     ├─> CON-02 (AI schema) ─> AI-01 (adapter, mock) ─> AI-02 (jobs) ─> AI-04 (confirm)     │
                     │                                                    │                  │          │
                     └─> CON-03 (match schema) ──────────────────────────────┐                 │          │
                                                                             v                  │          v
                                          OPT-01 (compat, matching) <────────────────────── BE-03, BE-05
                                                    │
                                                    v
                                          OPT-02 (optimizer) ─> OPT-03 (rounding checks)
                                                    │
BE-03 + BE-05 ─> BE-06 (reservations) ─> BE-07 (internal use) ─> BE-08 (analytics)
                         │                                              │
                         └─> QA-03 (race test)                          │
                                                                        │
BE-06 + OPT-02 ─> BE-09 (synthetic seed)                                │
                                                                        │
FE-01 ─> FE-02 ─> FE-03 (needs AI-02, AI-04) ─> FE-04 (needs OPT-02) ─> FE-05 (needs BE-08) ─> FE-06
                                                                        │
FE-05 + BE-09 + (AI-03 live or fallback) ─> QA-04 (end-to-end demo) ─> PIT-03 ─> PIT-04 ─> PIT-05
PIT-01 ─> PIT-02 ─> PIT-03
```

## 2. Critical path

`ARC-01 → CON-01 → BE-01 → BE-02 → BE-03 → BE-06 → BE-07 → BE-08 → FE-05 → QA-04 → PIT-03 → PIT-04 → PIT-05 → FIN-02`

Longest chain with optimization: `CON-03 → OPT-01 → OPT-02 → FE-04`. Optimization must not be left until the end: its output is needed for the plan screen and the demo.

The AI chain (`CON-02 → AI-01 → AI-02 → AI-04 → FE-03`) runs in parallel with the backend chain once BE-01 exists.

## 3. File and folder ownership

Each path has exactly one owner. Other agents may read it, but must not edit it. A change to a file owned by someone else goes through the orchestrator as a request.

| Path | Owner | Notes |
|---|---|---|
| `frontend/` | flutter-developer | `frontend/integration_test/` is owned by qa-engineer |
| `frontend/integration_test/` | qa-engineer | |
| `backend/app/api/`, `backend/app/services/` (inventory, reservations, impact), `backend/app/models/`, `backend/app/db/`, `backend/app/core/`, `backend/migrations/` | backend-engineer | Migrations: one agent at a time (see section 4) |
| `backend/app/schemas/` (general DTOs) | backend-engineer | |
| `backend/app/schemas/optimization.py` | backend-engineer owns file; optimization-engineer proposes changes | Shared contract |
| `backend/app/ai/`, `backend/app/integrations/vision/` | ai-engineer | |
| `backend/app/integrations/storage/` (Supabase) | backend-engineer | |
| `backend/app/optimization/` (or `services/matching`, `services/optimization`, pending ARC-01) | optimization-engineer | |
| `backend/tests/unit/`, `backend/tests/integration/` | backend-engineer | Except optimization and AI subfolders below |
| `backend/tests/optimization/` | optimization-engineer | |
| `backend/tests/ai/` | ai-engineer | |
| `backend/tests/e2e/`, `backend/tests/race/`, `backend/tests/contract/` | qa-engineer | |
| `docs/api.md` | backend-engineer | Changes require orchestrator approval |
| `docs/design/` | ux-designer | |
| `docs/qa/` | qa-engineer | |
| `docs/decisions.md`, `docs/orchestration/` | orchestrator | |
| `docs/demo.md` | qa-engineer (script), orchestrator (final) | |
| `docs/pitch/business/`, `docs/pitch/impact/` | business-analyst, impact-analyst | Own subfolders |
| `docs/pitch/pitch/` | pitch-strategist | |
| `docs/pitch/jury/` | jury-simulator | |
| `README.md`, `.env.example`, `.gitignore` | orchestrator | Only verified content |
| `CLAUDE.md` | user | Orchestrator may propose edits |
| `.claude/agents/` | user | Not edited during task work |

## 4. Shared contracts and coordination points

| Contract | Defined by | Consumed by | Change rule |
|---|---|---|---|
| `docs/api.md` (routes, DTOs, error envelope, status codes) | backend-engineer (CON-01) | flutter-developer, qa-engineer, ai-engineer (`/ai/*`), optimization-engineer (`/optimization/*`, `/ai/match`) | Orchestrator approves before any agent codes against a change |
| AI analysis schema | ai-engineer (CON-02) | backend-engineer (persistence), flutter-developer (display) | Schema version bumped on any field change |
| Compatibility function and match/optimizer schemas | optimization-engineer (CON-03) | backend-engineer (endpoints), flutter-developer (display) | One implementation only; both matching and optimizer import it |
| Design tokens and state list | ux-designer (CON-04) | flutter-developer | Changes noted in design README |
| Error envelope `code`, `message`, `details`, `request_id` | backend-engineer | all clients | Codes listed in `docs/api.md` |
| Database migrations | backend-engineer | ai-engineer (job table, if added), optimization (none expected) | Only one migration author at a time; ai-engineer requests a migration through the orchestrator |
| Synthetic demo fixtures | backend-engineer (BE-09) | qa-engineer, pitch-strategist (demo script) | Fixtures labelled synthetic |

## 5. Proposed execution plan (not approved)

The plan proceeds in waves. A wave starts only when its dependencies are `done`. Agents inside a wave run in parallel only where their owned paths do not overlap.

**Wave 0 — decisions and contracts (after APP-01 and BLK-01, BLK-04)**
- ARC-01 (orchestrator), ARC-04.
- Parallel: CON-01 (backend-engineer), CON-02 (ai-engineer), CON-03 (optimization-engineer), CON-04 (ux-designer). Each writes only its own docs; no code.
- Parallel with wave 0: PIT-01 (business-analyst) and QA-01 (qa-engineer), both documentation-only. PIT-01 waits for USR-03 facts or runs with assumptions marked.
- Gate 1 review: orchestrator checks contracts for consistency.

**Wave 1 — skeletons**
- BE-01 (backend-engineer). Alone on `backend/`. Creates the migration baseline.
- In parallel, owner paths disjoint: FE-01 (flutter-developer, `frontend/` only, against the contract, using mock responses in tests), AI-01 (ai-engineer, `backend/app/ai/` only, no migrations yet), OPT-01 (optimization-engineer, `backend/app/optimization/` only, pure functions with tests).

**Wave 2 — core backend**
- BE-02 → BE-03 → BE-04 and BE-05 (backend-engineer, sequential on `backend/app/api` and migrations).
- AI-02 after BE-03 (its job table requires the migration sequence). Coordinate the single migration author.
- OPT-02, OPT-03 in parallel with the backend (no shared files).
- FE-02 after BE-03 and BE-04 are verified against the contract.

**Wave 3 — transactions and integration**
- BE-06 (reservations, locking) → QA-03 race test. BE-07, BE-08 after BE-06.
- AI-04 (confirmation rule) after AI-02 and BE-03.
- FE-03 (needs AI-02, AI-04), FE-04 (needs OPT-02), FE-05 (needs BE-08).
- BE-09 seed after BE-06 and OPT-02.
- QA-02 contract check runs continuously from wave 2 onward.

**Wave 4 — demo and pitch**
- QA-04 end-to-end run. Any defect goes back to its owner with reproduction steps.
- PIT-02, PIT-03 (using only QA-verified features), PIT-04 jury scorecard.
- FE-06 and QA-05 only if P0 is complete.

**Wave 5 — final**
- PIT-05 revision, FIN-01 gates 4–5, FIN-02 rehearsal, FIN-03 README.

## 6. Parallelism rules

- Never run two agents on the same owner path at once.
- Never run two migration-touching tasks at once.
- Pitch agents may run at any time, but pitch claims are only written after the feature they describe passes QA.
- Frontend may code against a contract before the backend exists, but its tests use mocks, and integration waits for the real endpoint.
- The orchestrator waits for each returned result to be verified before starting the next task that depends on it.

## 7. Demo critical features

These must pass QA-04 before any pitch rehearsal:
1. Login as enterprise; create material; upload photo.
2. AI analysis (live, or the labelled fallback); human confirms.
3. Matching with reasons; plan with remainder.
4. Buyer request; seller confirms reserve; transfer; buyer confirms receipt.
5. Stock balance visibly changes; confirmed reuse recorded separately.
6. Analytics separates forecast from actual.
