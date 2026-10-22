---
name: feedback-no-papertrail-reads-in-app-logic
description: Treasury app logic must not read PaperTrail versions to rebuild past state; derive it from ledger entries
metadata:
  type: feedback
---

Don't make app code read PaperTrail (`versions`) to work out what state a record was in at some past time. Use the ledger: the `LedgerEntry` that moves the payment to its outgoing `GlobalAccount` dates the bank debit.

**Why:** on 2026-10-19 (3eb945e1), a draft reply to dcetlin's review of the month-end pending add-back proposed reading each wire's state at `as_of` from PaperTrail. Kevin: "oh whoa, no way. We do not want to read papertrail." Then: "why can't we use the LE where it's sent to the outgoing global account?" (example: OW 138422, LE 5943945).

**How to apply:** PaperTrail is an audit trail for humans and repairs. That is why console repairs use `update!` so a version gets written ([[feedback_console_repair_over_task_with_papertrail]]). It is not a data source for balances or state. If a past state can't be derived from ledger entries or the model's own timestamps, raise that with Kevin instead of reaching for `versions`.
