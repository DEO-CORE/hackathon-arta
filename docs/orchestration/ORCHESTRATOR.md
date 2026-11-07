# ARTA Orchestration

Owner: CTO / lead orchestrator (the main Claude Code session).
Source of truth for product rules: `CLAUDE.md` (currently stored as `Claude.md`; same file on macOS, rename pending).
Status: **setup only. No feature development has been approved.**

## 1. Roles

| Role | Who | Responsibility |
|---|---|---|
| Orchestrator | Main Claude Code session | Architecture decisions, task board, delegation, integration, quality gates, scope, risks, status reports |
| Development agents | `flutter-developer`, `backend-engineer`, `ai-engineer`, `optimization-engineer`, `qa-engineer`, `ux-designer` | Implement and verify their owned areas |
| Pitch agents | `business-analyst`, `impact-analyst`, `pitch-strategist`, `jury-simulator` | Evidence-based pitch material and critique |
| User | Project owner | Approvals, external accounts and keys, facts for the pitch, final decisions |

## 2. Operating constraints

- **Subagents are not orchestrators.** A subagent cannot start other subagents. All delegation goes through the main session.
- **No autonomous background work.** Agents run only when the orchestrator or the user invokes them, and they stop when they finish. The task board is updated by the orchestrator after each result is verified.
- **Parallel only on disjoint files.** Two agents may run at once only if their owned paths (see `DEPENDENCIES.md` section 3) do not overlap.
- **Verification before done.** A task moves to `done` only after its acceptance criteria are checked against real output (command output, test run, or a reviewed document). Agent claims alone do not count.
- **Agent configs are preserved.** Files in `.claude/agents/` are not edited without a recorded decision.

## 3. Decision rules

- Architecture decisions are recorded in `docs/decisions.md` (one entry each: date, decision, reason, alternatives, owner).
- A decision that changes an API, schema, or ownership boundary requires the orchestrator to update `docs/api.md` or `DEPENDENCIES.md` first.
- Decisions that need the user (keys, accounts, scope cuts, external facts) go to the user as an escalation, not a guess. See `TASK_BOARD.md` section 4.

## 4. Scope and time

- MVP scope is `CLAUDE.md` §2 and §17. Out of scope items stay out, including payments, delivery routing, custom AI training, government integrations, and Kyrgyz-language UI.
- Priority levels: **P0** (working MVP, AI, optimization, end-to-end demo, verified pitch), **P1** (UX polish, extra tests), **P2** (nonessential). P2 work is not started while any P0 is open.
- The 48-hour clock starts at the hackathon start time. **Record that start time here before implementation: `START = [user to provide]`.** Until it is recorded, the time plan in `CLAUDE.md` §17 is relative only.
- If a P0 task is at risk, cut P1 first. Never cut authorization checks, the balance invariant, human confirmation of AI output, or the separation of forecast and actual figures (`CLAUDE.md` §17).

## 5. Architecture baseline (proposed, to confirm)

- Flutter (Riverpod) → FastAPI → PostgreSQL; files in Supabase Storage (private bucket, signed URLs); vision AI behind an adapter; deterministic compatibility and solver in `backend/app/optimization/`.
- Solver: **one** of OR-Tools or SciPy `milp`. Proposed: SciPy `milp`, to keep dependencies small. Not yet decided; recorded in `docs/decisions.md` when approved.
- Optimization module location: proposed `backend/app/optimization/`. `CLAUDE.md` §12 names `services/matching` and `services/optimization`; the decision is pending.

## 6. Document map

| File | Purpose |
|---|---|
| `docs/orchestration/ORCHESTRATOR.md` | This file: roles, rules, status report format |
| `docs/orchestration/TASK_BOARD.md` | Tasks, owners, states, acceptance criteria, blockers |
| `docs/orchestration/DEPENDENCIES.md` | Dependency graph, file ownership, shared contracts, execution plan |
| `docs/orchestration/QUALITY_GATES.md` | Six gates with pass criteria and evidence |
| `docs/decisions.md` | Architecture and technical decisions (to be created) |
| `docs/api.md` | REST contract (to be created by backend-engineer) |
| `docs/design/` | UX specifications (ux-designer) |
| `docs/qa/` | Test plan, issue log, demo checklist (qa-engineer) |
| `docs/pitch/` | Pitch material (business, impact, pitch, jury) |

## 7. Status report format

Produced by the orchestrator on request, from the task board and the latest verified results only.

```
ARTA status — <date/time> — elapsed: <h> of 48 h (START recorded: yes/no)

MVP readiness:      <percent or gate status, e.g. Gate 2: not passed>
Completed (done):   <task IDs and one-line result>
Active (in_progress): <task IDs, owner, what is running>
Blocked:            <task IDs, blocker, who must act>
Next 3 priorities:  <1. … 2. … 3. …>
Pitch readiness:    <claims-check status, open placeholders count, last jury score range>

Verification notes: <tests actually run and their result; anything not run>
```

Rules for the report: say "not run" when a check was not executed. Do not report percentages for work that has no acceptance evidence.

## 8. Execution cycle

1. Pick the next `todo` task whose dependencies are `done`.
2. Set it to `in_progress` with an owner and start note.
3. Delegate to the owning agent with the task's acceptance criteria and owned paths.
4. On return, check the deliverables and run the verification commands in the task.
5. Set `done`, `blocked` (with reason and the action needed), or send it back to the agent with the failing check.
6. Update `TASK_BOARD.md` and, at each gate, `QUALITY_GATES.md`.
