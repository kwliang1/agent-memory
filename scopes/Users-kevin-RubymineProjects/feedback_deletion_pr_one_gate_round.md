---
name: feedback-deletion-pr-one-gate-round
description: "Pure code-deletion PRs need only one clean pre-push review round, not two"
metadata:
  node_type: memory
  type: feedback
  originSessionId: fa0e87cf-0eec-43f0-95e3-e131f7a0a045
  modified: 2026-10-21T17:19:41.767Z
---

For PRs that only delete dead code (plus regenerated output), one clean review round is enough to push. Kevin, 2026-10-21, venture BANK-2174 (removing orphaned ActivateCardModal).

**Why:** a deletion that nothing imports can't introduce new behaviour; the second round buys nothing.

**How to apply:** still run step 0 (gate checklist) and one round of 3 reviewers; push on the first clean round. Anything beyond deletion (new logic, renamed behaviour) gets the normal two rounds. See [[review-gate-playbook]].
