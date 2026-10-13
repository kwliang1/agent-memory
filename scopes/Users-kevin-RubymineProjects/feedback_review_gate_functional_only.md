---
name: feedback_review_gate_functional_only
description: "The pre-push gate terminates on no addressable FUNCTIONAL feedback; messaging and naming are Kevin's call at manual review"
metadata:
  node_type: memory
  type: feedback
  originSessionId: dbaff02e-c756-46e4-b80c-26d759043df3
  modified: 2026-09-26T20:38:40.694Z
---

The pre-push review gate stops when a round produces no addressable **functional** feedback.
Wording findings do not count and do not reset the successive-clean counter:

- operator-facing copy (flash text, error/refusal messages, preview labels)
- variable, method, and constant naming
- comment wording
- PR body, commit message, README, test names (added 2026-10-08)

Kevin reviews those himself during manual PR review. Reviewers may still report them — file them
in a separate section so they are visibly non-blocking — but a round whose only feedback is
messaging or naming counts as CLEAN.

Still functional, and still resets the counter: a message that is factually *wrong* about system
behaviour (e.g. "the change was rolled back" when an after_commit raised post-COMMIT), or advice
that steers an operator into a destructive path. The test is whether acting on the text produces a
wrong outcome, not whether the text reads well.

**Why:** at round 7 of BANK-2156 the gate was still resetting on findings Kevin would have just
fixed inline during review, which spends rounds without buying safety.

**How to apply:** say the bar in the reviewer prompt, and sort each round's findings into
functional vs. wording before deciding whether the counter advances.

**Still violated after this rule existed** (mined 2026-10-08): ~93 of ~520 gate resets were wording.
Nova rollup status ran 27 prose-only resets with code frozen since ~R12. Treasury bank-2150 lost 7.
Nova bcdb r6 reset on PR-body text, and treasury 06c3 R4 on comment wording. Delete a flagged
comment rather than rewriting it, because rewrites spawned new wording findings. Run one
non-blocking prose pass after the second clean round, not inside the counter.

Related: [[feedback_review_gate_count]], [[feedback_review-gate-five-reviewers]],
[[feedback_minimal-change-in-review-gate]].
