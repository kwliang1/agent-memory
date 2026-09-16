---
name: nova-payment-cancel-not-productized
description: "nova Payment/Distribution cancellation is DB/data-layer-enabled (transitionToCancelled fns exist) but NOT productized — no GraphQL mutation, admin tool, or UI reaches it. Verified 2026-08-05."
metadata: 
  node_type: memory
  type: reference
  originSessionId: 7158483e-ada7-4291-9276-6be123b2e151
  modified: 2026-08-05T23:42:14.599Z
---

Question (Capital Factory distribution thread, Connor/Jack wanting to "mark a payment cancelled" mid-flight): does nova have an in-product way to cancel a specific `Payment`? **Verified answer: No — DB-enabled, not productized.**

DB/data layer is fully built:
- `Payment.cancelledAt` col (`packages/prisma/models/banking.prisma:240`); `CANCELLED` is a *derived* state (`graph/src/data/banking/payment.ts:19,83`).
- `PAYMENT_CANCELLED` audit event (`banking.prisma:332`).
- State machine `CREATED→CANCELLED`/`PENDING→CANCELLED` (`payment.ts:308-314`).
- `transitionToCancelled(...)` fn (`payment.ts:318-353`), guarded to block if a linked transfer already `COMPLETED`.
- Distribution-level equivalent: `transitionToCancelled` (`graph/src/data/distributions/distribution.ts:460`), FSM `cancel` only valid from `DRAFT`.

No product surface reaches it (this is the whole gap):
- Both `transitionToCancelled` fns have **zero non-test callers**.
- Only `cancel*` mutation in the entire GraphQL schema is `cancelTransferControl` (`graph/schema.graphql:5725`) → cancels a `TransferControl` (approval item), NOT a Payment. No `admin*` payment-cancel mutation; no app/portal UI.

Closest existing surfaces (neither sets `Payment.cancelledAt`):
- "Reject payout" blade `app/src/components/views/Distribution/PipelineTab/DistributionPaymentBlade/index.tsx:296-350` → rejects pending `TransferControl` (`approved:false`), returns DistributionPayment to `STAGED`.
- `removeDistributionDraftEntity` (`graph/src/internal/schema/distribution/draftEntities/remove.ts:9`) removes a recipient only while distribution still an editable DRAFT — no path for a started/executed distribution (Jack's Cusseta case).

Productizing = wire existing `transitionToCancelled` → new service + GraphQL mutation + UI. Related distribution-polish issues: NOVA-3718 (done), NOVA-3680 ($0 dist). See [[nova-worktree-dev-gotchas]].
