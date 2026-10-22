---
name: iw-transfer-reads-original-sub-account
description: A repair task that drives an IncomingWire through IncomingWires::StateService.transfer! must pin original_sub_account, the CA's active sub, no AccountMerge, and assignment_type/wire_info, not just sub_account_id
metadata:
  type: feedback
---

`IncomingWires::StateService.transfer!` books the deposit from `original_sub_account`, not `sub_account`. It sends a real V2 FUNDS_MIGRATION when that differs from the CA's active sub (`forward_funds_to_active_sub_account!`), and revises ledger entries onto another CA if an `AccountMerge` exists. It also publishes the IW's Completed event to Venture. Venture starts `ClosingExecutionWorker` for assignment_type None/EntityUid, and an investment-wire worker when `wire_info` matches `/((I[- ])|(INV))[0-9A-F]{7}/`.

**Why:** a repair task that guarded only `sub_account_id` missed the real-money forward path and the Venture side effects; review caught both.

**How to apply:** in any undo-return or re-transfer task, verify! should pin [CA, sub, original sub, active sub, cents], refuse a merge, and pin assignment_type and wire_info by exact equality. Read the prod values first. Related: [[treasury-repair-task-gotchas]], [[feedback_no-fuzzy-description-matching]].
