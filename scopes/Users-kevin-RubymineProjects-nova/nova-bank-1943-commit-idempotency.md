---
name: nova-bank-1943-commit-idempotency
description: "BANK-1943 / PR #9871 state: per-attempt commit keys; matchmaking FSM has NO recovery sweeper — commitRowCore's settle-on-PENDING is the only reclaim; review-gate history and open Kevin calls"
metadata: 
  node_type: memory
  type: project
  originSessionId: ca52b8bd-f630-4b73-90ca-325c3713527d
  modified: 2026-09-09T23:14:29.049Z
---

Split into two PRs on 2026-09-04 at Kevin's call ("this is quite sprawling"): **#9871** = BANK-1943 proper (per-attempt keys, binding lifecycle, per-attempt plans, `ownerHoldsAccess`); **#9917** `kevinliang/bank-1943-recovery` stacked on it = the recovery nudge + mid-transition refusals + the false-commit guard. Both on `bank-1941` (#9830, still unmerged). Worktree `.worktrees/nova-comet`, test DB via `set -a; source .devcontainer/.env` → `localhost:8060/nova_nova_comet` (vitest appends `_test`).

Why it exists (the ELI5 Kevin asked for on 2026-09-03): the engine dedups by exact event key (`packages/fsm/src/engine/createFsm.ts` `findEventByIdempotencyKey` → `deduped: true`, runs nothing). Base key was per ROW (`commit:${rowId}`), so bounce → fix → re-commit was swallowed. Per-ATTEMPT key fixes it; the caller's key is only a content-hash guard binding.

**2026-09-09 — OVERLAP with #9932 (pick/deselect stack, base main).** #9871 is still OPEN (base main). The pick/deselect PR #9932 shipped an **interim** pick-scoped key — `resolveKey(args, matchedId) => args.idempotencyKey ?? commit:${rowId}:${matchedId}` (threaded to all 3 call sites: guardIdempotency binding, the FSM `commit` event in settleCommit, handleAlreadyCommitted lookup) — to unblock the *re-pick-a-different-candidate* dead-end after a bounce. Kevin's call (option 1): keep the interim on #9932, reconcile to #9871 when it lands. **#9871's per-attempt approach SUPERSEDES the pick-scoped interim** (it also fixes a *same-pick* re-commit + releases the binding on bounce). Both rewrite `resolveKey`/commit-idempotency → they WILL conflict in `commitRow.ts` on merge; whoever's second takes #9871's version. main's `resolveKey` is still the row-scoped base as of 2026-09-09.

Non-obvious facts the code won't tell you:
- **Stranding is a property of execution `status`, not `currentState`.** `processTransition` commits `{status:'ENTERING', currentState: target}` *before* running that state's onEnter, so EVERY onEnter is a stranding window — a death inside `stampCommitted` leaves a ported entity with the row projection still `PENDING` and the API answering `ALREADY_COMMITTED`. Gate recovery on status ENTERING/EXITING (the predicate `graph/src/services/fsm/executionReads.ts` `recoveryActionFor` already uses), not on a state name.
- The FSM recovery sweeper (`graph/src/lib/temporal/activities/recoverFsmEvents.ts`) is **distributions-only**; the admin recovery console has no matchmaking actions. So a commit is the ONLY recovery: #9871's `currentForCommit` fires one `process({ recoverStale: true })` nudge. `processEntity` drains the queue and returns `processedCount: 0` immediately when nothing is claimable — use the nudge, never a polled `settleRow`, as the probe: `recoverStale` only steals claims older than `defaultProcessingTimeoutMs` (5 min), so against a live drain a poll burns the full 5s `SETTLE_TIMEOUT_MS` (~200 rounds of advisory lock + N+1 event query) and returns the same answer.
- Test 43s fabricates the post-crash rows directly in `fsm_execution`/`fsm_event` (status ENTERING/PENDING + PROCESSING/phase ENTERING with a 6-min-old `processingStartedAt`); `enteringFromState` tolerates no history row. Mutation-checked: fails without the fix.
- `idempotencyKey` is a GLOBAL `@id` on `entity_matchmaking_commit_idempotency` — a blank key would be one binding shared by every row; resolvers and `resolveKey` both blank→default.
- Grant probe `holdsBankingGrantOnEntity` is deliberately stricter than live banking authz (Owner-role `OrganizationEntity` link AND both flags vs any link / either flag).

- **Two separate transactions in `processTransition`**: the execution's `ENTERING` status commits, then the event's phase stamp commits. The resume path (`createEventRouter`) gates on the *event* phase, so a death between them makes the event resolve against the already-advanced state → no edge → `IGNORED` → empty queue → no recovery is possible at all. One-line engine fix: gate the resume on `claimed.execution.status`. Shared with distributions — open decision on #9917.
- OPEN on #9917 (Bugbot, not yet refuted): a stale-claim re-run of the same `commit` event dedups its `committed` emit and keeps the FIRST payload, while `PLAN_TTL_MS` (2 reclaim windows) still holds the plan — so the re-run can port a *new* entity after the first tx rolled back, leaving marker and payload describing different entities.

Open Kevin calls: dedicated `OWNER_NOT_GRANTED` outcome vs reusing `IDEMPOTENCY_CONFLICT` (app copy in `BulkActionDialog.tsx` currently says "earlier commit attempt", misleading for dedup rows) — follow-up. Binding-before-emit crash window: pre-existing, escape hatch = same-owner replay or explicit key; documented, not fixed.

Gate history: every round A–K + round 1 (2026-09-03) found something real; never skip the second clean round on this branch. See [[nova-lp-porting-review-tab]], [[review-loop-attribution-discipline]].
