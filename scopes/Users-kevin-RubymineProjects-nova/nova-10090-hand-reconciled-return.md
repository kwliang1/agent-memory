---
name: nova-10090-hand-reconciled-return
description: nova #10090 (NOVA-3880) hand-reconciled-payment returns — review verdict, 3 blockers, and the FSM/bind architecture facts behind them
metadata:
  type: project
---

nova **#10090** `fm/nova-3880-return-reconciled` (yewon, OPEN, NOT merged) adds `treasuryTransferId` + `returnedAt` to `PaymentTransfer` so a bank return lands on a hand-reconciled payment. Adversarial review 2026-09-15 (3 rounds). **Review only — no code changed.** Kevin has NOT decided whether to file Linear issues or hand it to yewon as PR comments.

**Kevin's questions, answered:**
- *Block manual reconcile when a transfer exists?* **No** — nova creates a `Transfer` whenever it sends, so blocking on that turns the feature off. `findReconcileCandidates` (`data/distributions/distributionPayment.ts:1322-1329`) deliberately keeps transfer-backed rows; only INITIATED/PENDING are refused (`retryability.ts:43-45`).
- *Would a `paymentTransfer` exist for an offline payment?* **Yes** — `PaymentTransfer` is the attempt row; `transferId: null` means no nova `Transfer`. `createReplacement` (`paymentTransfer.ts:412`) is the ONLY producer and `manualReconcile/index.ts:139` its only caller, so a transfer-less row exists *because* manual reconciliation made it. Truly-offline money can't reach the path at all (`verifyLedgerEntryOwnership` requires a Treasury ledger entry), so the population is strictly *Treasury moved it, nova has no `Transfer` row*.

**3 blockers:** (1) a returned hand-reconciled payment is unrecoverable — retry/return-to-staged/cron-initiate/re-reconcile all refuse on `ledgerEntryId`, undo throws raw P2025; an *ordinary* return stays retryable (`RETURNED` ∈ `TERMINAL_ATTEMPT_STATES`), so the PR body's "same as a return on an ordinary transfer" is false. (2) `markUnusable` never called on the new return path → bank-confirmed-dead recipient account keeps being offered. (3) bind-side predicate parity (below).

## Three reusable architecture facts

1. **The payment FSM has NO `transferFailed` event** (`services/fsm/distributions.ts`, 18 events total). A bank failure moves the payment nowhere — so a failed transfer **strands it at `approval`**. Contrast: rejected control → `staged` (`:603`), RETURNED → `sent` (`:612`). This is the widest issue found and is unrelated to returns. It is also what makes "mint the missing `Transfer` row instead of adding the column" unsafe: a control-less minted transfer at `approval` satisfies every condition of `findApprovalWithoutControl` (`distributionPayment.ts:1679` inner-joins `transfer`, so today a transfer-less row is dropped) and gets **released to a final sent state**.
2. **`isReconcilableLedgerRow` is presentation-only.** `ledgerRowStateSource.ts:50-55` excludes reversal-status rows, wired at `entityFinancialAccount.ts:276` as a **GraphQL field resolver**. `verifyLedgerEntryOwnership` (`manualReconcile/index.ts:85-101`) never reads it. Same shape for `requesterTypes` (filtered at `reconciliation/index.ts:230`, not on the bind) and for amount/sign. **The option is prevented in the UI and available in the API** — that's the right lever for "prevent state drift", not a greyed-out button. Urgent as of this PR because `markReturned` now uses the bound entry's `requesterId` to decide which payment a return lands on.
3. **You cannot key a return off `ledgerEntryId`** even though it's already `@unique` (`banking.prisma:337`): nova's only ledger read is `batchGetLedgers`, keyed by *customer-account id*. Finding the entry needs the account → the entity → the payment, which is what you're looking for. Circular without a new treasury endpoint. **This is the strongest justification for the duplicated column and the PR doesn't state it.**

Also: treasury's `ledger_entry.requester` is **polymorphic** and `pagination_service.rb:122` falls back to the stringified integer PK, so `requesterId` is NOT reliably a transfer id — `manualReconcile/index.ts:96` claims otherwise. Junk values fail loudly (never equality-match) rather than misattributing.

Related: [[nova-9587-ach-return-failed-vs-returned]], [[nova-fsm-stored-definition-not-authoritative]], [[treasury-prophet-ledger-consumed-by-nova]]

## Kevin's ruling (2026-09-15) — the column is a bad smell, don't ship it

Kevin, twice: *"Any transfer in treasury (OutgoingWire, AchPush) should be represented in Transfer in nova as a principle"* and *"if the operator manually initiates a transfer from nova, they should be allowed to associate that transfer with a paymentTransfer, not link the treasuryTransferId itself directly."* So: **mint/associate a `Transfer` row at reconcile time; no raw `treasuryTransferId` on `PaymentTransfer`.**

I argued to keep the column and was wrong. Both objections collapsed:
1. *"needs a fabricated `transfer.completedAt`"* — **false.** `state` derives COMPLETED from the PT's **own** `completedAt` at `paymentTransfer.ts:157`, which sits *between* the two `transferId` branches (:145-155 does CANCELLED/FAILED only; :160 does INITIATED/PENDING). `stateWhereConditions.COMPLETED` never reads `transfer.completedAt` either.
2. *"control-surface release"* — real but **one predicate from moot**: `findApprovalWithoutControl` needs `AND latest.ledger_entry_id IS NULL`. A hand-settled payment should never be an approval-release candidate regardless. Arguably a bug in that query today.

Real remaining cost of minting: `reconcile`'s ledger-only branch is gated on `transferId: null` (`:627`), so the completion must be written **before** linking or that `updateMany` stops matching. (No DB check constraint actually enforces Transfer's sender/recipient despite the schema comment — only FKs.)

**Draft PR comments (nothing posted):** arti slug `nova-10090-draft-review-comments`. Awaiting Kevin — the design comment asks yewon to redo the central mechanism, so it's his to send.

Also found: existing `payment_transfer_terminal_state_check` counts `completed_at`/`failed_at`/`cancelled_at` but NOT `returned_at`. A hand-settled return sets completed+returned, which is correct — document it or someone "fixes" the constraint and breaks returns.
