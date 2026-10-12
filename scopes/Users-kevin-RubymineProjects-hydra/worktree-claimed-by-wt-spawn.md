---
name: worktree-claimed-by-wt-spawn
description: A hydra spawn can claim an existing .worktrees/<repo>-<name> directory, reset it to main on a wt/<name> branch, and silently move your session off its own commit
metadata:
  type: project
---

**Happened 2026-09-28, mid review-gate, to `.worktrees/hydra-comet`.**

A hydra session spawn creates a worktree at `.worktrees/<repo>-<sessionname>` on a branch `wt/<sessionname>`. If a directory of that name already exists — because an *earlier* session of the same name built it and you inherited it — the spawn **checks out `wt/<name>` at main over it**. Your HEAD silently becomes `main`, your working files become main's, and `git status` is clean, so nothing looks wrong.

**What tells you:** the harness reports "file changed on disk" for files you did not touch, and `git log --oneline -1` shows main instead of your commit.

**Nothing is lost if you committed.** The branch ref survives — it is not what got moved. Recovery:

```sh
cd <repo-root>                      # the main checkout, NOT the stolen worktree
git rev-parse <your-branch>         # confirm your commit is still there
git worktree add ../.worktrees/<repo>-<a-different-name> <your-branch>
cd ../.worktrees/<repo>-<a-different-name> && bun install   # a fresh worktree has no node_modules
```

**Do not reclaim the stolen directory.** A live session owns it now; checking your branch back over it restarts the fight and can strand that session. Take a new path. `git worktree list` shows who holds what, and `git branch --list 'wt/*'` shows the spawn branches.

**Consequence for a review gate:** any read-only reviewer you pointed at the old path may have spent part of its run reading main. Check each reviewer's citations against your actual code before counting its verdict — a reviewer that materialises the commit itself (`git archive` into /tmp) is unaffected, one that reads the path directly is not. A reviewer in its own `.claude/worktrees/agent-*` worktree is never affected.

Related: [[another-session-can-tear-down-your-worktree]] (the same class, different mechanism — that one deletes the dir), [[hydra-worktree-add-15s-timeout]], [[feedback_mutation-agents-corrupt-worktree]], [[shared-checkout-worktree-isolation]].
