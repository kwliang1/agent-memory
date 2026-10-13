---
name: nova-matchmaking-fsm-observability
description: "BANK-1897 o11y: the matchmaking row FSM is already fully measured by fsm.* metrics; the issue's FAILED-state backlog gauge watches a state prod rows never reach."
metadata:
  node_type: memory
  type: project
  originSessionId: 0a933a67-0831-456c-b641-8d1c79dac7dc
  modified: 2026-10-01T06:17:56.317Z
---

For BANK-1897 (instrument the matchmaking flow). Two corrections to the issue's own scoping,
both verified against `origin/main` and 30d of prod metrics on 2026-09-25.

**Most of the "missing domain metrics" already flow.** The FSM engine emits, all tagged
`fsm_namespace` + `fsm_name` (so `{fsm_namespace:entitymatchmaking, fsm_name:row}` scopes them):

- `fsm.transition.count` {from_state, to_state, outcome: completed|failed|ignored, event_type}
- `fsm.error.count` {phase, event_type}
- `fsm.emit.count` {outcome: accepted|deduped|rejected} + `fsm.emit.duration_ms`
- `fsm.action.count` {outcome} + `fsm.action.duration_ms`
- `fsm.outbox.written` {outcome}

The row states (`graph/src/services/fsm/entityMatchmaking.ts:493-504`) are exactly the issue's
wanted vocabulary, so "per-state row counts" and "port outcomes split by COMMITTED/FAILED/STALE"
are a dashboard query, and the error monitor is `nova-fsm-event-failed` with the namespace swapped.
Genuinely zero matchmaking domain metrics exist (`metrics.increment`/`distribution`) — the issue is
right about that, it just doesn't need most of them.

**Prod baseline, 30 days to 2026-09-25** (`fsm.transition.count` by to_state):
staged 565, conflict 331, auto_match 241, pending 210, committed 176, needs_review 130,
rejected 75, stale 4, no_match 1. `fsm.error.count` = **3**, all `phase:action`.
So `>= 1 in 15m` is the right threshold with no tuning.

**The acceptance criterion points at a state prod rows don't reach.** It asks for a monitor on
"rows parked in a terminal `FAILED`" — there were **zero** transitions into FAILED in 30 days.
FAILED is reachable only via the explicit `fail` event from PENDING (`entityMatchmaking.ts:541`),
which `runPort` emits on a *handled* port failure. All 3 failures in the window were the other
kind: an unhandled throw in PENDING's onEnter, which aborts the transition
(`to_state:pending, outcome:failed`) and strands the row mid-entry behind a FAILED event. The
backlog gauge should count rows stranded mid-transition — the shape #9917 fixed — not rows in FAILED.

**Recovery net (updated 2026-09-30).** #10558 (9/29) added `entityMatchmaking/row` to the
every-minute `recoverFsmEvents` sweep (`recoverRow`, 4 rows/tick). The sweep selects only PENDING
heads and stale PROCESSING claims — **never a FAILED head**, which is the prod stuck shape (ERRORED
execution). And the admin FSM nudge mutation (`AdminFsmWorkflow` in
`internal/schema/admin/fsmDistributions.ts`) accepts only `distribution`/`payment`, so there is
**no operator retry for a matchmaking row** at all — a FAILED head needs an engineer.

**BANK-2168** (branch `kevinliang/bank-2168`) adds `alertStuckMatchmaking` (15m) emitting
`entity_matchmaking.row.stranded_count` (reuses `findExecutionPage` recoverableOnly, gated on
execution `updated_at` older than 5m) and `entity_matchmaking.upload.scoring_stalled_count`
(SCORING uploads with no row-execution write in 30m — the upload has no "scoring since" column
because `getBatch` rewrites status on every read).

The datadog sync blocker ([[nova-datadog-sync-not-applying]]) was fixed by #10636 on 2026-09-30.

**Written up** as a 20-scenario coverage matrix (stage → score → review → port, signal that exists
vs. what watches it, plus sub-issues S1–S4):
https://arti.internal.angellist.com/s/nova-matchmaking-observability-coverage

Two gaps in that table have no proposal yet: Prisma pool exhaustion on a large batch, and
ipseity/treasury call health during the port. A third — matchmaking outbox failures — is
unmeasurable today: matchmaking emits through the outbox (`drive.ts:61`), but
`drainUnfinishedOutbox` is only called from `recoverFsmEvents`, so `fsm.outbox.failed_rows` never
fires for the matchmaking workflow at all.
