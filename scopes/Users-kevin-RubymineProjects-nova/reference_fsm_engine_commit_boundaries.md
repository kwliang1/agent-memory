---
name: reference_fsm_engine_commit_boundaries
description: "packages/fsm commit boundaries: ENTERING commits before onEnter runs; FAILED+ERRORED commit together; what that means for reading execution state"
metadata:
  node_type: memory
  type: reference
---

Facts about `packages/fsm` that are load-bearing for anyone reading `fsmExecution` / `fsmEvent` to
judge an entity's state. All verified by reading the engine on 2026-09-12.

**A transition spans three transactions** (`packages/fsm/src/engine/router/processTransition.ts`):
1. commits `{currentState: target, status: 'ENTERING'}` (~:117-122)
2. runs the state's `onEnter` **outside** that transaction (~:132)
3. commits the terminal status (~:159-168)

So an execution reads `ENTERING` for the **entire duration of its onEnter**. In nova matchmaking
that means every actively-porting row reads ENTERING while `runPort` does the real work — a healthy
row, not a stuck one. Never treat "not RUNNING/COMPLETED" as "broken": it is the normal state of any
transition in flight. The signal that separates live from stuck is the claim's age —
`recoveryActionFor` (`graph/src/services/fsm/recovery.ts`) already gates on `STALE_CLAIM_AFTER_MS`
and returns null for a fresh claim.

**A failure commits the event and the execution together**
(`packages/fsm/src/engine/router/eventLifecycle.ts:71-100`): `event.status = 'FAILED'` and
`execution.status = 'ERRORED'` are written on the same `tx`. So `{execution: RUNNING, head event:
FAILED}` is a pair **no consistent snapshot can return** — if you read the two tables in separate
statements you can observe it, and any verdict built on the pair will be wrong.

**Reading both tables therefore needs one snapshot.** Postgres READ COMMITTED re-snapshots per
statement, so a plain sequential pair is not enough — use one transaction at `RepeatableRead`. If
you also compare against a projection column in a third table, that read belongs in the same
transaction or the comparison spans two snapshots.

**Prisma interactive-transaction timeouts differ between prod and tests.** `graph/src/lib/prisma.ts`
sets `transactionOptions` from `config.PRISMA_TRANSACTION_MAX_WAIT`, which is **unset in
production** (Prisma defaults: 2s maxWait / 5s timeout) but set to 600s in `graph/vitest.config.ts`.
A P2028 under pool pressure is therefore a production-only failure the suite cannot reproduce —
decide the degradation behaviour deliberately rather than letting it surface as a 500.

Related: [[reference_treasury_transfer_state_machine]].
