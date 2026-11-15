---
name: ga14-intl-settlement-gap
description: GA 14 (international outgoing-wire settlement pool, GHB Main sub 166754) drifts from the bank; how to read its residual, why confirms fail, and how to trace the defects
metadata:
  type: reference
---
GA 14 is the `INTERNATIONAL_OUTGOING_WIRE_SETTLEMENT` pool. International OWs forward into it, and confirming a wire drains it to GA 9 (`EXTERNAL_OUTGOING_FUNDS`) through `transfer_funds_from_international_wire_account!`. A completed OW with no drain leg, or a short one, leaves GA 14 ledger above the bank. Repairs: #9115 (BANK-2269) and arti `inc-5843-ga14-rca`.

**Lessons**
- Before quoting a GA 14 residual, pull recent TP transactions and subtract wires that TP shows as sent but treasury still has as `submitted_offline`. An early −$6,667 figure was wrong for exactly this reason.
- A confirm books GA14→GA9 for the full amount and validates against GA 14's pooled balance, so any confirm larger than the pool fails with "insufficient funds" (INC-5843). The pool moves with other wires' in-flight cash, so the shortfall lands on **whichever wire confirms last**. Recheck the pool before forcing a completion; it often clears on its own.
- TP `acct_11hkntap104mscr/transaction` returns nothing before 2025-09-30. For older wires, match on amount, date and beneficiary, not IDs: TP forwards arrive as books *or* incoming wires, and `BookTransfer` covers only about 3% of books.
- When the write console's TP API has lapsed, `BalanceCheck::Record` for sub 166754 is the read-console view of the bank side.
- Defect patterns found (BANK-2269): a re-completion that drained after an SVB send, a forward revised away while its drain ran, and a second drain from a manual fix.
