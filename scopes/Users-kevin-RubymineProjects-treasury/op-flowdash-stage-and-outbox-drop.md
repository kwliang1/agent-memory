---
name: op-flowdash-stage-and-outbox-drop
description: "OutgoingPayment Flowdash \"stuck in requested\" = two bugs — wire stage mapping (requested→created, PR #8663) AND the Temporal outbox silently dropping the newest FD upsert when transitions cluster."
metadata: 
  node_type: memory
  type: reference
  originSessionId: 7bee1d38-0f64-47b3-a7f8-9546f9acb0ae
  modified: 2026-08-26T21:01:09.943Z
---

Banking ops reported OP **wires "stuck" in a `requested` Flowdash stage** they don't watch (Grace, 2026-08-24). Root cause is **two independent bugs**:

**Bug 1 — wire stage mapping (FIXED, PR #8663, branch `kevinliang/op-wire-flowdash-created-stage`).**
- Every `OutgoingPayment` is born in `requested` — the state machine's `initial:` (`app/models/outgoing_payment.rb:174`, `State::Requested`). `created` is NOT an OP state.
- Two Flowdash boards, two mappers in `lib/flowdash/workflow/banking/outgoing_payment_transfers.rb`: wire path uses `stage()` (guarded by `VALID_STAGES`, `:10`/`:140`), ACH path uses `ach_stage()` (unguarded). Legacy `outgoing_wire_transfers.rb` writes to the **same** `FLOWDASH_OUTGOING_WIRE_WORKFLOW_ID` (prod board `zlIywp`).
- `OutgoingWire` is `initial: :created` (`app/models/outgoing_wire.rb:207`) and legacy passes it through, so `created` is the lane ops actually works. OP wire mapper wrongly emitted `requested → requested`; ACH already had `requested → created`.
- Fix = `requested => created` in wire `stage()` + swap `requested`→`created` in `VALID_STAGES`. **Gotcha: a one-line remap RAISES** — `stage()` guards on `VALID_STAGES.include?(result)` and `created` wasn't in it. `VALID_STAGES` is read only by that guard; no other consumer.

**Bug 2 — Temporal outbox silently drops the newest FD upsert (NOT yet fixed).** This is the actual "stuck" cause and the reusable gotcha.
- `after_commit :upsert_flowdash_task` fires on every OP transition (`outgoing_payment.rb:138`) → `BackgroundOutboxActivityDispatcher` with a **stable per-OP `temporal_id`** `flowdash-upsert-outgoing-payment-task-#{id}` (`:830`).
- When `Flipper.enabled?(:temporal_outbox)` (TRUE in prod), `BackgroundOutboxActivityJob` calls `start_activity(id:)` and **rescues `Temporalio::Error::ActivityAlreadyStartedError` → logs at info and drops it** (`app/jobs/background_outbox_activity_job.rb`). `start_activity` is async; the job's `limits_concurrency to:1` only serializes the enqueue, not the in-flight activity.
- So when an OP fires create→await_ops→processing within ~1-2s (normal), the catch-up upserts collide with the still-running first activity and are silently swallowed. FD freezes at the last upsert that completed = the initial `requested`. Ops sees `requested` while treasury is already at `processing` (verified live: OP-1410/1499/1588 all `processing`, all `ExternalWireAccount`).
- "moved backward awaiting_ops_approval→requested" that ops saw is NOT a real transition — no such edge exists (`:332-405`); it's this drop artifact.
- Fix options: re-enqueue on the rescue (default `id_reuse_policy` is `ALLOW_DUPLICATE`, so a retry starts fresh and reads live state), or a terminal-state FD reconcile sweep, or don't collapse the id. Awaiting Kevin's steer on approach.

**Bug 2 ALSO hits the legacy `OutgoingWire` board (proven live, 2026-08-26 — Grace's "64 wires stuck in `provisioned`, treasury at ready-for-approval").** NOT an OP issue and NOT fixed by #8663 (that only remapped the OP `requested` stage string). These are legacy `OutgoingWire`s (states `provisioned`/`treasury_prime_ready_for_approval` don't exist on OP); legacy `OutgoingWireTransfers.stage()` passes state through unchanged so FD literally shows `provisioned`. Same outbox mechanism: `OutgoingWire after_commit :upsert_flowdash_outgoing_wire_task` → stable id `flowdash-upsert-outgoing-wire-task-#{id}` (`outgoing_wire.rb:788`). Clustering trigger = `OutgoingWires::StateService:524` `try_provision!(wire) && mark_as_treasury_prime_ready_for_approval!(wire)` — `mark_as_provisioned!` (:63) and `mark_as_treasury_prime_ready_for_approval!` (:74) each open their OWN `ActiveRecord::Base.transaction`, so two `after_commit`s fire ms apart → 2nd FD upsert collides with 1st still-running → dropped → FD frozen at `provisioned`. Direct proof: Datadog `treasury-worker` prod = 133 `flowdash-upsert-outgoing-wire-task-* already started, skipping` logs in 14d (wire ids 134286–134393, several dropped 2–3×). The generic outbox re-enqueue fix covers OP + OutgoingWire + every other model on the shared stable-id outbox.

Prod OP state facts: read-console `state_transition_history` fails (`s3:ListAllMyBuckets` denied on readonly role) — can't get transition timeline from `al console -p` read. `al console` read hit `treasury-ro` pod-get RBAC forbidden right after SSO login (propagation delay); a plain `al console create --no-attach` then `exec` worked. Write console = `no access to role GlobalConsoleWriters`. See [[treasury-prod-console-access]], [[treasury-nova-event-bridge]] (that's the OUTBOUND bridge — different direction).
