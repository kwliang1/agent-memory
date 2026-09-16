---
name: feedback_never_checkout_over_uncommitted_work
description: "Commit before any control experiment; `git checkout <ref> -- <paths>` destroys uncommitted work with no stash entry to recover from"
metadata:
  node_type: memory
  type: feedback
---

Before running a control experiment that reverts sources (e.g. "does this test fail on origin/main
too?"), **commit first**. `git checkout origin/main -- graph/src app/src` overwrites the index AND
the working tree, and unlike `git stash` it leaves nothing to recover from.

**Why:** I destroyed ~40 minutes of review fixes this way on BANK-1997. My existing note
([[reference_bare_worktree_bringup]] and the stash guidance) warned about `git stash` in shared
worktrees, so I reached for `checkout` instead — which is strictly worse, because a stash at least
leaves an entry.

**How to apply:**
1. `git commit --amend --no-verify` (or a WIP commit) BEFORE the experiment.
2. Run the control, then `git checkout HEAD -- <paths>` to restore — safe only because HEAD now
   contains the work.
3. Afterwards, verify the restore actually landed: re-grep for a distinctive symbol from each file
   you changed. A silent partial restore is the real hazard.

Related trap from the same incident: a Python/sed rewrite using `str.replace` **fails silently**
when the target text has moved (a formatter reflowed it, or a revert removed it). One of my
file rewrites no-oped and I reported the change as done; a reviewer caught it. Put `assert old in s`
before every replacement, and grep for the new symbol afterwards.
