---
name: nova-9587-ach-return-failed-vs-returned
description: "nova PR #9587 review — why a Treasury RETURNED reads as pipeline FAILED, and the one test gap to close before merge"
metadata: 
  node_type: memory
  type: project
  originSessionId: ca3e9b9b-62aa-4ed5-aae5-d63f0b7d821e
  modified: 2026-08-20T22:07:59.479Z
---

nova PR #9587 (`test(banking): cover the ACH return path`, author ywplee-al, Kevin reviewer, OPEN). Kevin asked: "if treasury reports returned, transfer state should be returned not failed, right?" Answer after 3-round adversarial review:

**Two layers, deliberately different:**
- **Transfer layer keeps the truth:** reconcile sets `Transfer.state = 'RETURNED'`, stamps `returnedAt`, records a `TRANSFER_RETURNED` payment event with the NACHA code. `TransferProgressState.RETURNED` is first-class (`services/transfer/progressState.ts`).
- **GP/recipient pipeline `progressState` collapses RETURNED→FAILED on purpose.** `DISTRIBUTION_PAYMENT_PROGRESS_STATES` / `RECIPIENT_PAYMENT_PROGRESS_STATES` have **no RETURNED member** (`paymentProgressState.ts:23`, `recipientProgressState.ts:22` — "no surface describes a payment to a GP as returned"). Guarded by ~5 pre-existing tests (paymentProgressState.test, recipientProgressState.test, DistributionCallout "never shows the word returned", DistributionPaymentTimeline). `progressState` is a **derived read-model GraphQL field — nothing branches on it operationally**; money decisions run off Transfer.state.
- Note `Payment.state` stays **PAID** after a return (recorded as event, not state transition — `distributionPaymentsForRecipient.test.ts`).

**FAILED is safe (retry is double-guarded):** `services/distribution/payments/retryFailedTransfer` → `retryability.ts`. `RETRY_BLOCKERS` includes `returned` + `settled`; a returned attempt blocks as `returned` (CANCELLED+treasuryTransferId branch) or `settled` (COMPLETED branch). Message: *"This payment was returned. Returned payments are resolved by support rather than sent again."* Double-send closed by `FOR UPDATE` row lock in `initiate` (pre-check is advisory). So nova FORBIDS self-service resend of a return — the returned word surfaces at the action point.

**The one real gap (recommended before merge):** #9587 never re-reads `paymentTransfer.state` after the RETURNED event — asserts only `transfer.returnedAt` + `progressState`. But `findRetryBlocker` keys entirely on `paymentTransfer.state`; the escape hatch `retryability.ts:61` (`states.includes('FAILED') ? undefined : 'noFailedAttempt'`) means a future reconcile mapping a return to bare `FAILED` would arm retry while #9587 stays green. **Fix:** add `expect(findRetryBlocker(attempts, new Set())).toBeDefined()` after the return (assert the guard *verdict*, not a raw state value — survives COMPLETED↔CANCELLED refactors). Plus: dual-layer clarifying comment, description trim ("end to end" = detection/recording), follow-up ticket for the always-blocked retry button rendered on returned payments.

Related: [[op-errored-state-requeue]] (treasury-side OP return semantics).
