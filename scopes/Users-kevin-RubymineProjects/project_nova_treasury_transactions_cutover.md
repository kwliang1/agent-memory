---
name: project_nova_treasury_transactions_cutover
description: Making treasury payment activities the only transaction list in nova: where the plan lives, the decisions Kevin made, and the one visible product change
metadata:
  node_type: memory
  type: project
  originSessionId: 812a213e-adea-4adb-a5cb-4ee171e4c6ac
  modified: 2026-10-16T21:56:07.769Z
---

Plan artifact: https://arti.internal.angellist.com/s/nova-treasury-transactions-plan-2026-10-16 (v4 has the issue table). The Linear project "Balance & Transactions Cleanup" (teams Nova Foundations + Nova, lead Kevin) holds every issue and both artifacts; read the project for current issues and status.

Kevin's decisions (2026-10-16): no stored `state` column on payment_activities, derive and filter from the payment; `payment_activities.index` stays account-scoped (callers resolve the account from the transfer's VBA); migrate every `transfers.index` caller now; pre-dispatch transfers show only in Needs Review. Nova stays as dumb as possible: it compares against the payments treasury says are pending and hydrates its own details.

Visible change to flag in review: recipients stop seeing "fund approval pending" incoming rows (nova `lib/entity/financialAccounts.ts` recipient-side pending had no treasury-id requirement).

**Why:** the nova UI still ran the old ledger + pendingTransfers path while REST v1 already used PaymentActivities; the per-row `transfers.index` lookups were the hidden coupling.

**How to apply:** when a later session picks up any of this work, read the artifact first; the states filter must invert the per-model state tables in `TreasuryEvents::Transfers::InfoService`, not add a column. See [[project_payment_activity_stack_review]].
