---
name: piermont-operating-account-untracked-invoice-debits
description: CA 298977 (AngelList's Piermont Operating Account) fails the balance check when ALV invoices are paid straight from the bank; treasury only learns via a manual entry
metadata:
  type: project
---

CA 298977 / sub-account 380709 / TP `acct_11j8mb721gq78t4`. The monthly flow is BaaS interest wires in (~the 2nd) and a wire to AL Advisors out. Both are ledgered automatically.
ALV invoices are paid from the bank outside treasury, so they only reach the ledger as hand-made console entries. July's ($12,090.55, LE 5830583, booked 2026-08-27) first credited the SVB-scoped EXTERNAL_OUTGOING_FUNDS and broke the FBO check (INC-5556/5560). It must use the **Piermont** external sub-account.

Confirmed 2026-10-06: the bank paid TP `txc_15wp72e2gb7d477y` 2026-09-08 -$10,063.20 "August Invoice #12 2026". Harsohail booked it the same day as LE 5918206. The correct shape is from July's corrected entry LE 5832253 (the original 5830583 was deleted): origin CA 298977, destination GlobalAccount 20, from_sub_account 380709, to_sub_account nil, WITHDRAWAL. The bank posts each invoice ~4 weeks before anyone books it.

**How to apply:** for a gap on this account, diff the run history first (GraphQL `balanceCheckRecords(runUuid:, search:"298977")` from Kevin's Chrome session works when the console is down), then look for a bank debit with no matching ledger entry.
