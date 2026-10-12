---
name: linear-cancel-closes-linked-pr
description: "Cancelling a Linear issue makes Linear's GitHub integration CLOSE its linked PR (as Kevin) within a second — never cancel an issue whose branch/PR is still meant to merge"
metadata:
  node_type: memory
  type: feedback
  originSessionId: 0c12266a-b6ce-4835-b0ce-74ea8ae43c61
  modified: 2026-10-07T19:18:53.383Z
---

2026-10-07: I cancelled BANK-2238 at 19:18:02 while its branch `kevinliang/bank-2238` (PR #9075) had been repurposed to carry BANK-2236's change. Linear closed #9075 at 19:18:03 under kwliang1. Kevin: "wait it shouldn't be closed. I need to merge 9075". Reopened via `gh api .../pulls/9075 -X PATCH -f state=open`.

**Why:** Linear links PRs to the issue named by the branch, and its cancel sync closes them. Also, merging a stacked PR into its parent branch marks that PR's issue Done in Linear before anything reaches main.
**How to apply:** before cancelling a Linear issue, check `attachments` for open PRs; if any must still merge, leave the issue open (or move to In Review) instead. When a branch is repurposed, expect its issue to be auto-transitioned by PR events.
