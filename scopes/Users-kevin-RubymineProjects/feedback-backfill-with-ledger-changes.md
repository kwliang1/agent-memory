---
name: feedback-backfill-with-ledger-changes
description: "When designing ledger/bookkeeping pattern changes, always plan a backfill maintenance task for historical data — don't ship the new write path without it"
metadata: 
  node_type: memory
  type: feedback
  originSessionId: de729de9-cc28-4767-8a20-99b5d540a619
---

When a design introduces a new ledger entry pattern (e.g. position legs for MMF buys/sells against a new GlobalAccount), the design phase MUST include a backfill maintenance task for historical records as a first-class deliverable — not a follow-up.

**Why:** BANK-1474 shipped `complete_buy_with_position_legs!` / `complete_sell_with_position_legs!` creating position legs against EXTERNAL_MMF_HOLDINGS for new orders, but no backfill task was planned for the ~150 historical buy/sell orders. The first sell to hit the new code path in production (sell #145, LE 5703238) inflated CA 311536's cash_balance by $1M because it was the only order with a position leg — the balance math (position legs cancel CT completion LEs) only works when ALL orders have position legs, not just new ones.

**How to apply:** During design/planning of any ledger, bookkeeping, or double-entry pattern change:
1. Enumerate all existing records that would need the new pattern
2. Write the backfill maintenance task as a companion deliverable in the same milestone
3. Plan deploy ordering: balance-read exclusions first → backfill → UI changes
4. The backfill must be idempotent and safe to run while the new write path is live (use `ledger_entry_id IS NULL` guards)

See [[always-reply-via-tool]] for communication context.
