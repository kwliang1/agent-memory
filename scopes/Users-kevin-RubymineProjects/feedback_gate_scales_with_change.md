---
name: feedback-gate-scales-with-change
description: Size the pre-push gate to the change; a rebase, rename, simple refactor, pure deletion or internal-tool change gets one clean round, and test gaps alone don't reset the counter
metadata:
  type: feedback
---

The two-clean-round gate is for new behaviour on a money or production path. Smaller changes get a smaller gate:

- **Rebase only, no new code:** no new round.
- **Rename or simple refactor:** one clean round.
- **Pure deletion of dead code:** one clean round.
- **Internal single-user tools (hydra, Daedalus, agent-memory code):** one clean round with two reviewers, and no ops lens ([[feedback-daedalus-no-ops-lens]]). Prose-only memory changes skip the gate ([[feedback-no-gate-for-memory-prose]]).
- **Test-gap findings:** fix them, but they don't reset the counter.

**Why:** Kevin cut the gate back nine times in two weeks (Oct 2026), each time after a session had run the full gate on one of these, sometimes past round 10. In his words: "this is a simple refactor, 1 review gate is sufficient" and "spec gaps should not count against 'clean' counter". The gate catches subtle invariants in new logic. A change with no new logic has none to catch.

**How to apply:** when the gate starts, name the tier in one line in the status reply, e.g. "rename only, so one clean round". Still run step 0 (the gate checklist) and the tests. Anything that adds or changes behaviour gets the normal two rounds. If Kevin names a different bar, use his. Hub: [[review-gate-playbook]].
