---
name: feedback_gate_placement_carries_preconditions
description: "Moving a condition downstream to make a sweep reach it silently drops the preconditions the original call site enforced — check what the surrounding branch already guaranteed"
metadata:
  node_type: memory
  type: feedback
---

**BANK-2149, review rounds 4→5, 2026-09-29.** I moved a completion condition out of a call site and
into the shared service method so a Temporal sweep would also reach it. Two reviewers had (correctly)
found the call-site version had no retry path. The move introduced a worse bug.

The original call site sat inside `case response[:status] ... when 'sent'`. That branch was carrying
an unstated precondition: **Treasury Prime has confirmed the payment actually left.** Moving the
condition into `attempt_to_complete!` dropped it, because the only remaining bar there was
`transfer.can_complete?` — a state check, not an arrival proof. Consequences:
- the 30-min sweep completed the transfer while TP still had the ACH `pending` and **cancellable**
- it drained a real bank account against a credit that had not arrived
- and `mark_as_errored` transitions only from `[:submitted, :processing]`, so once `completed` a
  later TP error webhook **could not transition and the Slack page was silently swallowed** — a
  stall Ops noticed ~20 times would have become one nobody sees

**The rule.** Before relocating a condition, ask what the enclosing branch already guaranteed. A
`when 'sent'`, an `if record.confirmed?`, a rescue block, a callback ordering — these are
preconditions even when nothing names them. Write them down, then check the new home still has them.

**The diagnostic that generalises:** every other completion bypass in treasury has an independent
arrival proof (`ach_sync_service` matches an incoming txn, `incoming_wire_sync_service` matches a
wire, `to_sub_account.svb?` has no TP settlement concept). When adding a new bypass, ask what *its*
arrival proof is. If the answer is only "the record is in a state that permits it", that is not one.

Related: [[feedback_minimal-change-in-review-gate]] — the retry gap the move was fixing was real but
second-order (a missed webhook still alerts via `CrossTransfer.stalled`), while the regression the
move introduced was first-order. Prefer the smaller correct fix and document the limitation.
