# ARTA Quality Gates

A gate passes only when every criterion has evidence attached. Evidence means a command that was run with its output, a reviewed document with a path, or a recorded manual run. An agent's statement alone is not evidence.

Status values: `not started`, `in progress`, `failed`, `passed`.

| Gate | Name | Status |
|---|---|---|
| 1 | Architecture and API contracts | not started |
| 2 | Frontend/backend integration | not started |
| 3 | AI and optimization validation | not started |
| 4 | End-to-end demo | not started |
| 5 | Evidence-based pitch review | not started |
| 6 | Final rehearsal | not started |

---

## Gate 1 — Architecture and API contracts

**Pass criteria**
- [ ] `docs/decisions.md` records stack, solver choice (one only), optimization module location, AI adapter location, auth approach.
- [ ] `docs/api.md` covers every route in `CLAUDE.md` §9, with DTO field types, status codes and the error envelope.
- [ ] Decimal values are strings in every DTO; no float for money or mass.
- [ ] `docs/design/` has states for every MVP screen.
- [ ] AI schema (CON-02) states that composition, weight, strength and safety are not determined from photos.
- [ ] Compatibility function signature (CON-03) is defined once and named as the only implementation.
- [ ] Ownership table in `DEPENDENCIES.md` section 3 has no path with two owners.
- [ ] `CLAUDE.md` naming is resolved (`CLAUDE.md` exists as the filename).

**Evidence:** links to the files; orchestrator's written consistency review.

**Failure triggers:** two routes for one action; DTO field missing from either side; solver choice unresolved.

---

## Gate 2 — Frontend/backend integration

**Pass criteria**
- [ ] `python -m alembic upgrade head` runs on an empty PostgreSQL database. Output recorded.
- [ ] `python -m pytest` passes for the backend. Output recorded.
- [ ] `python -m ruff check .` and `python -m ruff format --check .` pass. Output recorded.
- [ ] `flutter pub get`, `dart format --output=none --set-exit-if-changed lib test`, `flutter analyze`, `flutter test` run and pass. Output recorded.
- [ ] Contract check (QA-02) passes against the running API: status codes and error envelope match `docs/api.md`.
- [ ] Flutter calls the real API (not a mock) for: login, material create, material list, requirement create.
- [ ] No widget in `frontend/` contains HTTP, SQL, or allocation logic (grep check recorded).
- [ ] Authorization checks: a buyer token cannot read another organization's draft material (QA-01 matrix).

**Evidence:** command outputs; QA-02 report; grep output.

**Failure triggers:** any test not run; API returns a shape the client does not parse; any secret found in the repository (checked with a grep for key patterns and `.env` tracked files).

---

## Gate 3 — AI and optimization validation

**AI**
- [ ] Mock-provider tests pass: valid, invalid JSON, schema violation, timeout, unknown composition handled.
- [ ] Stale `input_version` cannot confirm a changed material (test output).
- [ ] No code path writes confirmed attributes from AI output (grep and test).
- [ ] Live provider: one real analysis run on a synthetic photo, output read by a human, result labelled "live" in the report. **If not run, the report says "live AI not verified" and the demo uses the labelled fallback.**
- [ ] AI outage test: catalog and manual entry still work.

**Optimization**
- [ ] Known small instance with hand-computed optimum passes.
- [ ] Shared demand across several materials respected (test).
- [ ] Incompatible pairs get zero allocation (test).
- [ ] Minimum-lot behaviour tested (test).
- [ ] Repeat runs on the demo fixture give identical output (test).
- [ ] `feasible` and `heuristic` statuses are never labelled optimal (test).
- [ ] Baseline is feasible on the same inputs (test).
- [ ] Post-rounding balance, demand and compatibility checks pass (test).
- [ ] Matching and optimizer import the same compatibility function (test).

**Evidence:** test output; the solver name and version; the demo fixture hash or input snapshot.

**Failure triggers:** any AI output reaches stock or allocation tables directly; any optimization result reported as optimal without a solver optimal status.

---

## Gate 4 — End-to-end demo

**Pass criteria** (run on a freshly migrated database, with the seed command from the README)
- [ ] Race test QA-03 passes on PostgreSQL: one success, one 409, no negative stock. Output recorded.
- [ ] Idempotency test: repeated reservation, confirm, cancel, transfer and complete create no duplicate transaction or impact record.
- [ ] Demo steps in `docs/demo.md` each run once, with the result recorded:
  1. Enterprise login; create material; photo upload.
  2. AI analysis (live, or the labelled fallback mode named in the report); human confirms.
  3. Matching with reasons; allocation plan with remainder and baseline comparison.
  4. Buyer submits request; seller confirms reserve; transfer; buyer confirms receipt.
  5. Available stock changes as expected.
  6. Confirmed reuse recorded separately; forecast labelled as forecast.
- [ ] No manual database edits during the run.
- [ ] Failures logged in `docs/qa/issues.md` with severity; all blocker issues resolved.
- [ ] Demo run time recorded.

**Evidence:** QA-04 report with step results and timestamps.

**Failure triggers:** any blocker open; any step that required a manual data fix; a demo step that uses a feature not in the product.

---

## Gate 5 — Evidence-based pitch review

**Pass criteria**
- [ ] Every claim in `docs/pitch/pitch/` appears in `claims-check.md` with a label: verified (with source), assumption (with register ID), or demo (labelled synthetic).
- [ ] No traction, revenue, pilot, interview, partnership, or environmental figure is verified unless a source file exists. Otherwise it is a labelled placeholder.
- [ ] Every product claim matches a feature that passed Gate 4. Features not built are described as roadmap.
- [ ] AI claims match the boundary in `CLAUDE.md` §6 (suggest, confirm, rules decide, solver calculates).
- [ ] Transfer and reuse are never conflated; forecast and actual are never conflated.
- [ ] Commission rate (5%) is labelled as a hypothesis.
- [ ] Jury scorecard (PIT-04) exists; each score is labelled an estimate; the five priority fixes are addressed or consciously deferred with a reason.
- [ ] Business and impact registers have no unlabelled assumption in the pitch.

**Evidence:** `claims-check.md`; `jury/scorecard.md`; the list of open placeholders with owner.

**Failure triggers:** any unsourced number in a slide or script; a claim the demo does not show.

---

## Gate 6 — Final rehearsal

**Pass criteria**
- [ ] Full 3-minute run-through, timed; within 3 minutes when read at normal pace. Time recorded.
- [ ] Full 5-minute run-through, timed; within 5 minutes. Time recorded.
- [ ] Demo run-through with the fallback path rehearsed once, even if the live path works.
- [ ] Q&A round completed with the question bank in `docs/pitch/jury/questions.md`; each answer rated; weak answers rewritten.
- [ ] Final README: every command was run; no nonexistent script; env variable names match `.env.example`; AI mode (live or demo) stated; limitations listed; economic assumption source linked.
- [ ] Final status report (format in `ORCHESTRATOR.md` section 7) issued with no unverified claims.

**Evidence:** rehearsal log with times; README verification notes; final status report.

**Failure triggers:** a rehearsal step depends on a manual fix; README lists a command that was not run.

---

## Gate review procedure

1. The owning agent returns its deliverables and its own check results.
2. The orchestrator re-runs the verification commands itself, or reads the saved output, and records what it saw.
3. Each criterion is ticked only with evidence in hand.
4. Any failed criterion sets the gate to `failed`, and a task is created or reopened in `TASK_BOARD.md` with an owner.
5. The gate moves to `passed` only when all its criteria are ticked.
