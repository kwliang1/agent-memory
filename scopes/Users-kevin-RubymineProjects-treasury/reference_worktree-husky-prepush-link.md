---
name: reference_worktree-husky-prepush-link
description: "Worktree push fails on missing .husky/_/husky.sh — symlink it from main checkout, don't reach for --no-verify"
metadata: 
  node_type: memory
  type: reference
  originSessionId: f6815ccc-19b2-4577-b925-7da274ee1af8
  modified: 2026-09-04T20:31:16.428Z
---

In a treasury worktree, `git push` can fail with `.husky/pre-push: line 2: .husky/_/husky.sh: No such file or directory`.

Fix it properly instead of `--no-verify` (Kevin: "don't let `--no-verify` become the way you get past a hook that's telling you something"). Replicate what `make setup-worktree` does — just the symlink step, not the whole target (which also runs a schema load):

```sh
mkdir -p .husky/_
MAIN_HUSKY="$(git worktree list --porcelain | head -1 | sed 's/worktree //')/.husky/_/husky.sh"
ln -s "$MAIN_HUSKY" .husky/_/husky.sh
```

Push then runs with the hook active and passes.

Related: [[reference_worktree-precommit-hook-stale-main]] (the docs-check hook's bogus huge file list — audit `origin/main...HEAD` instead).
