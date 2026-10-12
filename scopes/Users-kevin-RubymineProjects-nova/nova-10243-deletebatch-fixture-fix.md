---
name: nova-10243-deletebatch-fixture-fix
description: "nova #10243 — deleteBatch fixtures seeded the retired status column after #10086; plus four real follow-ups the gate surfaced"
metadata: 
  node_type: memory
  type: project
  originSessionId: 6947172c-d08c-4a4c-8047-8d43db59cc54
  modified: 2026-09-17T19:17:14.657Z
---

nova PR **#10243** (branch `kevinliang/fix-delete-batch-pending-guard`, opened 2026-09-17, base main `ee28e8c82a`). Unblocks red main: three `deleteBatch` tests asserted a mid-commit batch is refused but the delete succeeded.

**Root cause:** #10086 (`5d2432e5a1`) moved a matchmaking row's state from `entity_matchmaking_row.status` to `fsm_execution.current_state`, and did not update `deleteBatch.test.ts` / `deleteBatch.race.test.ts`. Those fixtures wrote the column and created no execution, so `ROW_STATE_SQL`'s `LEFT JOIN` missed and every row read `STAGED`. Only the PENDING cases failed — `countCommittedOrPortedRows` still reads the column, so COMMITTED rows were caught by that second query.

**Production was never broken.** `packages/fsm/src/engine/router/processTransition.ts` commits `currentState:'PENDING'` in its own transaction *before* line ~134 runs `onEnter` (= `runPort`). The new read fires strictly earlier than the column write it replaced, so #10086 narrowed the race window rather than widening it.

**Follow-ups found by the review gate, none fixed here — the first is the important one:**
1. `runPort`'s `if (!row) throw` is nested inside its `if (!plan)` branch. On the live-plan path with a deleted row, the `status = PENDING` write is the *only* thing that raises P2025 before `executePort`. That write dies with the column, which `packages/prisma/models/matchmaking.prisma` schedules for deletion — after which a delete that wins the race strands a real Entity + recipient org + financial account. **Must land before the column drop.**
2. `deleteBatch` takes `FOR UPDATE` on `entity_matchmaking_upload` + `entity_matchmaking_row` but reads its decision from `fsm_execution`, which it never locks. `store.withEntityLock` is a `pg_advisory_xact_lock`, so it cannot contend. The right guard is a predicate on in-flight work (`fsm_event.status IN ('PENDING','PROCESSING')` or execution `status IN ('ENTERING','EXITING')`), not a bigger lock — but it needs an escape hatch for a wedged event.
3. `matchmaking.prisma`'s doc on `status` says "Nothing reads this" — false, `countCommittedOrPortedRows` does.
4. `selectCandidate.test.ts`'s `stageTwoTinConflict` mints an **unsalted** `ent_inc` ipseity id; its two siblings salt with `${runId}`. On a re-used local DB run 2 dedups onto run 1's Entity, the financial-account upsert then collides on `handle @unique`, and the row lands FAILED instead of COMMITTED. See [[nova-tests-self-poison-warm-db]].

Also: `scripts/worktree/ports.sh` searches only 50 consecutive offsets from a `cksum` seed — measured 78 of 500 free with none in its window, so `just worktree-init` fails outright. See [[feedback-two-reviewers-per-round]].
