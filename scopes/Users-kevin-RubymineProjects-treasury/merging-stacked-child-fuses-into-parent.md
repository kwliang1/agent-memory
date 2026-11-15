---
name: merging-stacked-child-fuses-into-parent
description: Merging a stacked child PR whose base is the parent branch lands it inside the parent, so the parent's auto-merge ships both
metadata:
  type: feedback
---

When a child PR's base is the parent's branch (a Graphite stack), merging the child lands its commits in the parent branch, not main. A squash of the parent then ships both as one commit. On 2026-10-22, ipseity #1690 (the 422 behaviour change) merged into #1689's branch. #1689's auto-merge then put it on main hours before the venture consumer fix (#37855) was deployed.

**Why:** a "merge the child last, after consumers deploy" plan silently breaks. Reverting the squashed parent also removes whatever the parent added that downstream bumps need (here `EntityAPI::ErrorCategory`).

**How to apply:** for a deploy-ordered stack, merge the parent first and retarget the child to main before merging it. If a child has already merged into the parent, disable the parent's auto-merge until consumers deploy. Related: [[project_bank2341-client-error-contract]].
