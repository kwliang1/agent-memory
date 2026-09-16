---
name: nova-3569-stalled-transfer-alert
description: "NOVA-3569 DONE (PR #9247 merged 2026-08-07) — Temporal-scheduled alert for approved transfers never dispatched to Treasury"
metadata: 
  node_type: memory
  type: project
  originSessionId: 8ed8ea59-3449-4b23-b908-3691f6a58f0d
  modified: 2026-08-10T17:38:30.234Z
---

NOVA-3569 (INC-5376 follow-up): alerting for transfers approved/CLEARED but never dispatched to Treasury (`completeTransfer` is fire-once, no reconciler/retry — strands silently).

**Status: DONE.** PR #9247 (`feat(banking): alert on approved transfers not dispatched to Treasury`) squash-merged by Kevin on 2026-08-07 (merge commit `1f31a3c`); Linear NOVA-3569 → Done. Branch `kevinliang/nova-3569`, worktree `nova/.worktrees/nova-3569` at `c0e73e4`.

**What shipped:** detector for `treasuryTransferId: null` ∩ control `state: CLEARED`, `failedAt/cancelledAt: null`, `paymentTransfer: null` (excludes distribution payments — they have their own retry loop), 1h threshold. Runs as a **Temporal scheduled workflow** (`alertStalledTransfers`, every 15m, `LOW_EFFORT`, `SKIP` overlap) — migrated from cron per AWM's review (WALLET-27: cron fires per-pod, Temporal singleton fixes duplicate emits). Emits `transfer.dispatch.stalled_count` Datadog metric (every run → no-data means detector broke) + `dispatchCause` log enrichment (deepest *tagged* `client:treasury:*` cause) + monitor-as-code under `ops/datadog/`.

**Naming:** `stranded`→`stalled` throughout (Kevin's rename). Query drives from the selective undispatched-transfer side (indexed `@@unique([treasuryTransferId])`), not the ever-growing CLEARED set — kept intentionally after review pushed to invert.

Monitor notify-route + threshold are placeholders gated behind `DD_APPLY_ENABLED` (repo convention). Uses nova [[nova-worktree-dev-gotchas]] worktree flow.
