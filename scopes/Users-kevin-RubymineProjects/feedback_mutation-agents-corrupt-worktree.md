---
name: mutation-agents-corrupt-worktree
description: "Review agents doing mutation testing revert/edit source in the SHARED worktree, corrupting the working tree mid-gate"
metadata: 
  node_type: memory
  type: feedback
  originSessionId: 93d1ce31-249f-49e2-b40a-68d3d847bf70
  modified: 2026-07-24T19:09:24.985Z
---

During the BANK-1486 pre-push review gate, test-coverage review agents did mutation testing (revert a source line to pre-fix, re-run the spec, confirm it fails) **in the shared worktree**. They left the working tree dirty — reverted lines + stray `.bak` files (`check_service.rb.bak`, a reverted `record_type.rb`, a stripped `.where.not` filter). This made OTHER concurrent reviewers see "phantom" changes and report false Criticals, and once nearly caused me to mis-diagnose a real bug.

**Why:** parallel review agents run in the SAME git worktree; a mutation-testing agent's edits are visible to siblings and persist if it doesn't clean up.

**How to apply:**
- The committed HEAD is never affected — agents mutate the working tree, not commits. So the deliverable is always safe; verify HEAD (`git show HEAD:<file>`), don't trust the working tree mid-gate.
- After a review round, restore the tree: `git checkout HEAD -- <files>` + `rm -f **/*.bak` before committing/pushing.
- Do NOT edit files yourself while review agents are reading (they'll see half-applied state).
- Prefer read-only reviewer agents (the `reviewer` agent type has no Edit/Write) for verification rounds, or give mutation-testing agents `isolation: "worktree"` so their edits stay in their own copy.

Also: I once stalled a whole day waiting on a single background agent's completion notification that never fired (it hung). **Never block indefinitely on one agent's notification** — set a fallback (Monitor/poll) or proceed after verifying state directly.
