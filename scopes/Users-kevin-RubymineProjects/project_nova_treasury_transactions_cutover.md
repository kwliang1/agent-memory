---
name: project_nova_treasury_transactions_cutover
description: Plan + Linear issues (2026-10-16) for making treasury payment activities the only transaction list in nova; decisions Kevin made and the one visible product change
metadata:
  node_type: memory
  type: project
  originSessionId: 812a213e-adea-4adb-a5cb-4ee171e4c6ac
  modified: 2026-10-16T21:56:07.769Z
---

Plan artifact: https://arti.internal.angellist.com/s/nova-treasury-transactions-plan-2026-10-16 (v4 has the issue table).
Linear project: Balance & Transactions Cleanup (P-BANK-1806, teams Nova Foundations + Nova, lead Kevin) is the home for every issue and both artifacts. Umbrellas: BANK-2282 (treasury, Kevin) and NOVA-861 (nova, Yewon).
Balance work (from the "pulse" session): BANK-2310 = treasury#9000 (In Review), BANK-2311 net-change endpoint (Todo), BANK-2299 admin page, NOVA-897 = nova#10958 (In Review, blocked by BANK-2310), NOVA-898 net change consumption, NOVA-896 = nova#10980 (Done).
Issues: BANK-2307 states filter, BANK-2308 error_message/return_code on the activity message, BANK-2309 MMF orders (follow-up);
NOVA-891 prod diff, NOVA-892 hydrate by payment id, NOVA-893 transfers.index readers → payment_activities.index, NOVA-894 activity table from the transactions service, NOVA-895 drop nova pending rows.

Kevin's decisions (2026-10-16): no stored `state` column on payment_activities, derive and filter from the payment; `payment_activities.index` stays account-scoped (callers resolve the account from the transfer's VBA); migrate every `transfers.index` caller now; pre-dispatch transfers show only in Needs Review.

Visible change to flag in review: recipients stop seeing "fund approval pending" incoming rows (nova `lib/entity/financialAccounts.ts` recipient-side pending had no treasury-id requirement).

**Why:** the nova UI still ran the old ledger + pendingTransfers path while REST v1 already used PaymentActivities; the per-row `transfers.index` lookups were the hidden coupling.
**How to apply:** when a later session picks up any of these issues, read the artifact first; BANK-2307's filter must invert the per-model state tables in `TreasuryEvents::Transfers::InfoService`, not add a column. See [[project_payment_activity_stack_review]].
