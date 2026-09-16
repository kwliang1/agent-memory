---
name: nova-9777-insufficient-funds-block
description: "PR #9777's pre-insert funds guard shipped and produced its first prod blocks on 2026-08-31 (gryphon-17-llc wire); how to recognize and triage the error."
metadata: 
  node_type: memory
  type: project
  originSessionId: 742b312f-5199-41b6-be25-4e5397fe9af9
  modified: 2026-08-31T16:26:36.477Z
---

Nova PR **#9777** ("fix(banking): guard transfers against insufficient funds", merged 2026-08-28 17:25 PT, commit `62f181fe11`) reached prod and produced its **first-ever** insufficient-funds rejections on **2026-08-31 at 14:26 UTC** (Datadog Error Tracking issue `ff4fd24e-a547-11f1-9a86-da7ad0900002`, `first_seen_version` `603b0b06`).

**How it surfaces to users:** `createBankTransfer` fails with GraphQL code `BAD_USER_INPUT` and field error keyed to **`amount`** — `"There aren't enough funds in the account to send this transfer."` The input is *not* malformed; the code is misleading. Thrown at `graph/src/internal/schema/entity/financialAccount/bankTransfer/create.ts:263` via `graphQLErrors.ts:81`.

**What the guard actually compares** (`services/transfer/create/index.ts`, ~line 80):
- `getBalance()` → Treasury `treasury.customer_accounts.balance`, the **account-level available balance**. This *excludes* still-settling incoming ACH (3-business-day hold), so it is routinely lower than the DIBS/total balance ops sees in the UI. Erik Syvertsen confirms that gap is by design.
- minus `sumCreatedAmountBySenderVba` (`data/banking/transfer.ts:152`) — all transfers on that **one sender VBA** with `treasuryTransferId IS NULL` and all five state timestamps NULL. That set includes transfers merely awaiting control approval *and* permanent orphans (see [[nova-transfer-balance-reservation-traps]] trap 2).

**Triage recipe.** Before blaming the guard, get the reservation sum:

```sql
select t.sender_virtual_bank_account_id, count(*), sum(t.amount)
from transfer t
join virtual_bank_account v on v.id = t.sender_virtual_bank_account_id
join entity_financial_account e on e.id = v.entity_financial_account_id
where e.handle = '<handle>'
  and t.currency = 'USD'
  and t.treasury_transfer_id is null
  and t.returned_at is null and t.cancelled_at is null
  and t.failed_at is null and t.completed_at is null
group by 1;
```

Sum ≈ 0 → the block is honest; the money genuinely isn't available yet. Sum material → phantom reservations; cancelling those rows unblocks the wire.

**Outcome of the first incident: phantom reservations.** gryphon-17-llc VBA `8b3304ee…` held **8** CREATED transfers totalling **$4,831,895.68**, oldest 2026-05-28 — three months of orphans that were harmless until #9777 started counting them. Before cancelling orphans, reconcile each against Treasury by `Transfer.id` (it doubles as the Treasury idempotency token, `packages/prisma/models/banking.prisma:453`) — a null `treasuryTransferId` means nova never recorded an id, not that Treasury never accepted it.

**Don't be fooled by the stalled-transfer alarm.** `Approved transfer cleared but has no Treasury transfer id recorded` (`lib/temporal/activities/stalledTransfers.ts:35`, service **nova-temporal**, not nova-graph) fires ~100+ times per window, but it re-logs the same 8 tiny test transfers for org `ed679e84-8baa-4462-a104-4737dbaa1f87` every 15 min across prod **and** staging. It is unrelated to most incidents, and it only catches transfers whose control was *cleared* — it will never show a CREATED row still awaiting approval.

First incident: Trailmark / `gryphon-17-llc`, $27,400 OUTGOING_WIRE, 7 attempts by Brandon Byrd and Hailey Pizzutello, reported in Slack C0B8X6MJMKJ.

Related: [[nova-transfer-balance-reservation-traps]], [[nova-banking-permission-403]]
