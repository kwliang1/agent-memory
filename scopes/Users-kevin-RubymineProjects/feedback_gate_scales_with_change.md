---
name: feedback-gate-scales-with-change
description: Size the pre-push gate to the change; a rebase, rename, simple refactor, pure deletion or internal-tool change gets one clean round, and test gaps alone don't reset the counter
metadata:
  type: feedback
---

The two-clean-round gate is for new behaviour on a money or production path. Kevin cut it back nine times between 2026-10-08 and 2026-10-21, each time after a session ran the full gate on a low-risk change:

- **Rebase only, no new code:** no new round. "what's this last round of reviews for? it was just a rebase" (cc1ab1f8, 10-08, round 15 started after a restack).
- **Rename or simple refactor:** one clean round. "this is a simple refactor, 1 review gate is sufficient" (3c27585d, 10-15). "one clean review is fine. doesn't need two full gates" (5e9da7cc, 10-15, round 23 on a pure class rename).
- **Pure deletion of dead code:** one clean round. "one gate should suffice. these are pure file deletions" (bff26a65, 10-19), and the same call on venture BANK-2174 (fa0e87cf, 10-21).
- **Internal single-user tools (hydra, Daedalus, agent-memory code):** one clean round, two reviewers is enough, no ops lens. "just 1 clean round is fine" (71076914, hydra, 10-13). "2 reviewers and 1 clean round is fine" (412b6d19, hydra, 10-18, round 11). See [[feedback-daedalus-no-ops-lens]]. Prose-only memory PRs skip the gate: [[feedback-no-gate-for-memory-prose]].
- **Test-gap findings:** don't reset the counter. Fix them, then count the round as clean. "spec gaps should not count against 'clean' counter. call it as 1" (b5b83b14, treasury BANK-2220, 10-13).

**Why:** the gate catches subtle invariants in new logic. A change with no new logic has none to catch, so extra rounds only spend tokens and wall-clock. Two of the quotes above came after more than 10 rounds.

**How to apply:** when the gate starts, name the tier in one line in the status reply, e.g. "rename only, so one clean round". Still run step 0 (the gate checklist) and the test suite. Anything that adds or changes behaviour gets the normal two rounds. If Kevin names a different bar, use his. Hub: [[review-gate-playbook]].
