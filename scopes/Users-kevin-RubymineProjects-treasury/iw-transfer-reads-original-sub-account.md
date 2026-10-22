---
name: iw-transfer-reads-original-sub-account
description: A repair task that drives an IncomingWire through IncomingWires::StateService.transfer! must pin original_sub_account, the CA's active sub, no AccountMerge, and assignment_type/wire_info, not just sub_account_id
metadata:
  type: feedback
---

`IncomingWires::StateService.transfer!` books the deposit from `original_sub_account`, not `sub_account`. It sends a real V2 FUNDS_MIGRATION when that differs from the CA's active sub (`forward_funds_to_active_sub_account!`), and revises ledger entries onto another CA if an `AccountMerge` exists. It also publishes the IW's Completed event to Venture. Venture starts `ClosingExecutionWorker` for assignment_type None/EntityUid, and an investment-wire worker when `wire_info` matches `/((I[- ])|(INV))[0-9A-F]{7}/`.

**Why:** BANK-1745 (PR #9181). The IW 313170 repair guarded only `sub_account_id`, and three round-8 reviewers caught the real-money forward path. Round 9 caught the Venture side effects.

**How to apply:** in any undo-return or re-transfer task, verify! should pin [CA, sub, original sub, active sub, cents], refuse a merge, and pin assignment_type and wire_info by exact equality. Read the prod values first. Related: [[treasury-repair-task-gotchas]], [[feedback_no-fuzzy-description-matching]].
