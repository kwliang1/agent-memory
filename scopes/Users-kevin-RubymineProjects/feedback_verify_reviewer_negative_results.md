---
name: verify-reviewer-negative-results
description: "A reviewer's \"I tried and couldn't exploit it\" is much weaker evidence than their positive findings — re-test those yourself"
metadata: 
  node_type: memory
  type: feedback
  originSessionId: 4ec6b8f7-b778-4a89-bc02-c318ce388fd4
  modified: 2026-09-16T23:36:54.979Z
---

In a review, a reviewer's **positive** findings ("here is the exploit") are checkable and usually
sound. Their **negative** ones ("I tried to build an exploit and couldn't — non-blocking, no action
required") are the weakest claim in the whole review, and the highest-yield place to spend your own
verification budget.

Concept-seeding gate, 2026-09-16, 3 rounds. Twice the reviewer's negative result was wrong:

- Round 2 closed clean with one "asymmetry, not a defect I can demonstrate" — a begin-marker lookup
  that wasn't fence-aware. Their analysis stopped at "a later real assignment overwrites the fake
  one" and never asked what happens when **there is no later assignment**: a fenced example
  supplying a field the real block omits turned a refusal into a load. Fixed over their explicit
  "no action required"; they conceded in round 3.
- Round 3 prescribed a specific fix (refuse duplicate keys). It closed two of three variants and
  left the *supply* variant open. Shipping the prescribed fix verbatim would have shipped the hole.

**Why:** a reviewer proves a positive by construction and a negative by failing to imagine one.
Failure of imagination is not evidence. Their negative is a *lead*, not a verdict.

**How to apply:** when a round closes clean but names something it couldn't exploit, try to build
the exploit before accepting the round. Two rules bend here and both should:
[[feedback_minimal-change-in-review-gate]] (fix only what the finding requires) and
[[feedback_freeze_tree_during_review_rounds]] (don't edit under running reviewers) — a
*demonstrated* hole in code you introduced outranks a tidy round count, but an undemonstrated worry
does not. The discriminator is whether you can show the failing case, not how plausible it sounds.
Same test applies to a reviewer's prescribed fix: reproduce, then check it closes every variant of
the class, not just the one they showed. See also [[feedback_review_gate_count]].
