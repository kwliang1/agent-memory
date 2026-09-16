---
name: treasury-nova-event-bridge
description: "Prophet/NATS treasury→nova event bridge — architecture, service names, and how to scope its exceptions vs the loud non-bridge noise."
metadata: 
  node_type: memory
  type: reference
  originSessionId: 4205e2d5-87e0-40f2-bb11-29c76765bba7
  modified: 2026-07-31T05:47:39.239Z
---

The treasury→nova "event bridge" = **Prophet over NATS JetStream** (NOT webhook/SNS/Kafka).

**Producer (treasury, Ruby):** state-machine transitions on Transfer / OutgoingPayment (+ ach_push/ach_pull/outgoing_wire/incoming_wire) → `create_state_change_event!` / `publish_state_change_event!` → persist `TreasuryEvent` row → `TreasuryEvents::PublishJob` → `PublishService.publish!` → NATS subject `treasury.events.<event_type>` (prefix `treasury.events`, `X-Event-Type` header carries routing). Runs on `service:treasury-worker`. Retries ≤25; unlimited on `NATS::IO::ConnectError/Timeout`.

**Consumer (nova, TS):** runs INSIDE the **nova-graph** process (`service:nova-graph`, NOT nova-worker). `graph/src/clients/treasury/consumer.ts` `Prophet.startConsumer({stream:'treasury', handler: handleTreasuryEvent})` → dispatches on `X-Event-Type` to `handleTransferStateChange` (INTERNAL only) / `handleOutgoingPaymentStateChange` (ACH_PUSH/PULL, OUTGOING_WIRE) / `handleTransfersEligible` → enqueues Temporal `reconcileTreasuryStateChange` workflow → `services.paymentTransfer.reconcile`. Failures → Prisma `treasuryEventDeadLetter` (PENDING_RETRY). Wire states: QUEUED/PROCESSING/COMPLETED/FAILED/RETURNED/CANCELLED.

**Scoping exceptions — the traps (from 90d DD+Sentry sweep 2026-07-30):**
- The bridge is INBOUND (treasury→nova). Do NOT conflate with **outbound** nova→treasury *initiation* (`Failed to execute Treasury transfer`, `PaymentTransfer initiation permanently failed`, `outgoing_wires.create insufficient balance`, `initiatePaymentTransfer` ALREADY_EXISTS) — those are ~14k events but a different direction, mostly expected $0-balance rejections.
- Biggest NATS numbers (`StreamNotFound` 166k, `ConsumerNotFound` 12k) are the **ipseity→treasury** consume bridge, **staging-only, resolved May 2026** — misleading, exclude.
- Treasury exceptions live in **Sentry** (project `treasury`), NOT DD error-tracking. Nova in both (`nova-graph`).
- `"Failed to find or create PaymentTransfer"` is an identical string on BOTH inbound reconcile AND the outbound distribution cron — split by stack only.

**Actual bridge health (corrected after 3-lens adversarial review — first-draft conclusions were partly wrong):**
- Reconcile ERROR-path is genuinely low-error: **0 inbound reconcile permafailures/90d** against a real denominator ~101k treasury events published/30d, ~2,152 reconcile runs/30d. But "no systemic loss" was NEVER measured.
- **CORRECTIONS to avoid repeating:** (a) NoStreamResponse publish failures are NOT silent loss — `TreasuryEvent` row persists before publish, `PublishJob` has no `discard_on` so exhausted jobs land in `solid_queue_failed_executions`, and `after_id/after_uuid` replay scopes exist → "delayed delivery / manual replay," not loss; occurrence counts (1,697) are retry-inflated (~21/25 per event). (b) The zero-amount `transfer_positive_amount_check` (23514) bug is OUTBOUND (`initiate/index.ts:439`), not the reconcile bridge. (c) The "9,983 state-mismatch" figure is unreproducible — real ~3,100 INFO skips, logged as a bare string at `activities/reconcile.ts:34` so it forms no DD/Sentry issue. (d) Hot-log retention is ~15d — log-grep counts are ~15d slices, only Sentry/error-tracking span 90d.
- **Real standing gaps (missed first pass):** (1) consumer ACK-drops ~4,323/90d unhandled event types with ZERO handler code (`incomingpayments.statechangeevent` 4,122 + crypto 201) via `consumer.ts default → logger.info` — un-triaged; (2) `treasuryEventDeadLetter` is WRITE-ONLY (`deadLetter.ts:18`, no reader) so its depth = permanent inbound loss — never queried (nova prod DB unreachable); (3) rising July "Error starting treasury event consumer" 674×.
- Convergence gap: RETURNED handler records `TRANSFER_RETURNED` but never sets `completedAt`.

**Linear ownership (no dedicated "event bridge" project):** reconcile half is owned by Nova Product's **"Distribution <> Transfer Reconciliation"** (active, yewon) + **"Transfer Reconciliation V2"** (Backlog, connor.harlander). A prior automated audit already found+FIXED the sharpest silent-loss path: **NOVA-3429** (Done) "paymentTransfer transition swallows transient errors as 'skipped' → Treasury terminal events can be acked and permanently lost" (`paymentTransfer/transition/index.ts:85`) — de-risks the "benign skip = silent loss" worry. **NOVA-2071** (Backlog) covers silently-swallowed money-path errors / no error span (= the unhandled-drop o11y class). **NOVA-3220** (In Progress) = reconciliation monitoring. Unhomed gaps: consume-side DLQ drain, unhandled-event-type drops, BANK-1211 cron cutover, consumer-start reliability.

See [[nova-transfer-kyc-event-vs-poll]] (BANK-1211 = "Rip out paymentInitiation cron", Todo, the event-adoption follow-up to NOVA-871), [[nova-banking-permission-403]], [[nova-prod-db-access-from-bridge]].
