---
name: agent-memory-worktree-is-production
description: In ~/agent-memory the working tree IS production — a branch switch changes the live CLAUDE.md rules and the live memory store
metadata:
  type: project
---

`~/.claude/CLAUDE.md` is a symlink to `~/agent-memory/config/CLAUDE.md`, and every
`~/.claude/projects/*/memory` is a symlink into `~/agent-memory/scopes/`. Both resolve to the
**working tree**, not to a commit. So `git checkout` in that repo is not a local operation: it
rewrites the rules every session reads and the memories every session recalls.

**This bit on 2026-09-29.** Kevin's edits to `config/CLAUDE.md` (review gate 5 reviewers -> 3, plus
two Git Workflow rules) had been live and uncommitted since 25 September. I committed them on a
branch, then switched the checkout back to `main` — and the live rules instantly reverted to
"5 reviewers" for every session, because main did not carry the commit yet. Recovered with
`git checkout <branch> -- config/CLAUDE.md`, which restores the content into the working tree
without moving the checkout.

Corollary worth knowing before you panic at `git status`: **that repo is always dirty.** 84 modified
and untracked files under `scopes/` is the steady state, not a problem — it is sessions writing
memories. Do not "clean it up".

**How to apply:** before any checkout/rebase/reset in `~/agent-memory`, diff what the switch touches
against what is dirty:

```sh
comm -12 <(git diff --name-only HEAD <target> | sort) <(git status --porcelain | awk '{print $2}' | sort)
```

Empty means the switch is safe. Then check `config/` separately even if it is clean in that list —
if the target branch has a different `config/CLAUDE.md`, the live rules change the moment you switch.
To land an edit without a window where the rules regress, merge the PR first, then fast-forward.

Related: [[feedback_never_checkout_over_uncommitted_work]], [[feedback_use_worktree_for_other_branches]],
[[shared-checkout-worktree-isolation]], [[claude-md-ancestor-loading-rules]].
