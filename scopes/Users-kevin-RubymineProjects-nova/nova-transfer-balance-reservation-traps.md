---
name: nova-transfer-balance-reservation-traps
description: "Five non-obvious traps when reviewing nova transfer/balance code: VBA vs financial-account granularity, permanent orphan CREATED transfers, initiate bypassing ops.validate, no as-of marker on Treasury balances, and a payment/VBA lock-order inversion."
metadata: 
  node_type: memory
  type: project
  originSessionId: eed5d8c4-3704-4bd2-8ff9-9783dd617417
  modified: 2026-08-28T19:49:09.914Z
---

Found while reviewing PR #9777 (insufficient-funds guard) on 2026-08-28. Each cost real digging and applies to any nova banking work that reasons about available balance.

**1. Balance and reservations are measured at different granularities.** `getBalance({ treasuryAccountId })` hits `batchGetCustomerAccountBalances` for the *EntityFinancialAccount's* customer account. But transfers are keyed on `senderVirtualBankAccountId`. EFA→VBA is **1:many by design**, not a convention: `data/entity/virtualBankAccount.ts` picks `purpose === 'PRIMARY'` out of a list, and the model carries `subjectType`/`subjectId`/`purpose` earmarking. So any per-VBA sum or `FOR UPDATE` compared against that balance misses sibling VBAs on the same account.

**2. Orphan CREATED transfers are a permanent state.** A Transfer commits before the Treasury call. If `ops.execute` fails in `services/transfer/create/index.ts`, the row stays `treasuryTransferId = null` with no terminal timestamp forever. `markAsFailed`/`markAsCancelled` in `lib/banking/transfer/transitions.ts` have **no production callers**. Harmless historically, but fatal for anything that treats unsubmitted CREATED rows as live claims. Control rejection/cancel *does* cascade a cancel (`submitReview`, `cancelControl`); nothing else does.

**3. `initiate` never calls `ops.validate`.** The distribution payment path builds its own `resolveTransferData` and only touches `transferOperations` for `inputIds`. So the per-rail guards (USD-only on internal/ACH push, ACH max amount) do **not** protect the initiate path. Don't assume a validate guard covers distribution payments.

**4. The Treasury balance response has no as-of marker, so a reservation gate can't be made race-free.** `clients/treasury/operations/customerAccounts/batchGetBalances.ts` returns exactly `id`, `total_balance_cents`, `available_balance_cents`, `total_balance_end_of_last_month_cents`. No timestamp, version, or sequence. So any scheme that excludes submitted transfers (`treasuryTransferId: not null`) on the theory "the balance already reflects them" has an open window whenever the balance is read *before* the lock — and nothing exists to order the snapshot against. Reading it under the lock means holding `FOR UPDATE` across an HTTP call. Treat such a gate as best-effort; a Treasury-side as-of marker is the prerequisite for soundness.

**5. Lock-order inversion between the two payment paths.** `PaymentTransfer.paymentId` is a mandatory FK, so inserting a PaymentTransfer takes `FOR KEY SHARE` on the Payment row, which conflicts with `FOR UPDATE`. `initiate` locks payment → VBA; `paymentTransfer/create` locks VBA → (PT insert) payment. ABBA deadlock (40P01) between a cron tick and a mutation on the same payment. `transfer/create` is NOT affected — its insert's FK is the VBA it already holds `FOR UPDATE` on.

**6. Fail-open is only safe where orphan cleanup exists.** The codebase's existing policy is fail-open: `assertClearingWouldNotOverdraw` catches balance errors and "blocks only on positive evidence of an overdraft, since Treasury is the source of truth and rejects a real overdraft at execution" (`wouldOverdraw.ts:192-195`). But fail-open on the *direct* `transfer/create` path manufactures orphan CREATED rows (trap 2) at outage scale, because nothing reconciles them. The distribution path is safe — temporal transitions the Transfer on a terminal Treasury state (`createAndLinkTransfer.ts:248`). Also note `withinTransaction` passes no options to `prisma.$transaction`, so Prisma's `maxWait: 2000` / `timeout: 5000` defaults apply — never put an HTTP call inside it. And `getBalance` collapses transport errors and genuine misconfiguration (missing `alIpseityEntityId`) into one untyped throw, so a blanket fail-open swallows real data problems.

Also: `toCentsStrict` (packages/core money) throws on a 3rd decimal, neverthrow's `.map` doesn't catch, and `withinTransaction` rethrows non-`TransactionRollbackErr` — so a throw inside a Result chain escapes as an unhandled rejection and kills the whole batch.

Related: [[nova-cdc-changes-system]], [[nova-destroy-distribution-payment]], [[treasury-nova-event-bridge]]
