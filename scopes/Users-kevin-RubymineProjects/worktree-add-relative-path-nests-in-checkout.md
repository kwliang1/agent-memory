---
name: worktree-add-relative-path-nests-in-checkout
description: "`git worktree add treasury-worktrees/x` from inside treasury/ nests the worktree in the checkout; always use the absolute sibling path"
metadata:
  node_type: memory
  type: feedback
  originSessionId: 6b41c7e4-459b-4fe1-8b5b-91e45b791919
  modified: 2026-10-14T16:42:20.288Z
---

Treasury worktrees live in the sibling dir `~/RubymineProjects/treasury-worktrees/`. A relative `git worktree add treasury-worktrees/<x>` run with cwd inside `treasury/` creates `treasury/treasury-worktrees/<x>` instead — an untracked dir inside the checkout. Three separate sessions did this (8/17, 10/4, 10/9); Kevin called it misguided and had it deleted 2026-10-14.

**Why:** bash cwd persists across calls ([[bash-cwd-persists-across-calls]]), so a session that `cd`'d into treasury earlier silently resolves the relative path there.

**How to apply:** always pass the absolute path: `git -C ~/RubymineProjects/treasury worktree add ~/RubymineProjects/treasury-worktrees/<name> ...`. Same for any repo's sibling `<repo>-worktrees`.
