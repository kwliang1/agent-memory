---
name: feedback-no-papertrail-reads-in-app-logic
description: Treasury app logic must not read PaperTrail versions to rebuild past state; derive it from ledger entries
metadata:
  type: feedback
---

Don't make app code read PaperTrail (`versions`) to work out what state a record was in at some past time. Use the ledger instead: the `LedgerEntry` that moves a payment to its outgoing `GlobalAccount` dates the bank debit.

**Why:** a draft proposed reading each wire's past state from PaperTrail to compute an as-of balance. Kevin: "oh whoa, no way. We do not want to read papertrail."

**How to apply:** PaperTrail is an audit trail for humans and repairs. That's why console repairs use `update!`, so a version gets written ([[feedback_console_repair_over_task_with_papertrail]]). It is not a data source for balances or state. If a past state can't be derived from ledger entries or the model's own timestamps, raise it with Kevin instead of reaching for `versions`.
