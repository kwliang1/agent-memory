---
name: stash-push-noop-applies-foreign-stash
description: "A tagged `git stash push -- <path>` on a clean path stashes nothing; grepping for its SHA returns empty and `git stash apply \"$SHA\"` then applies ANOTHER session's stash@{0}"
metadata:
  type: feedback
---

On 2026-10-01 (treasury BANK-2200) I mutation-checked with `git stash push -m tag -- <file>`, ran the spec, then `git stash apply $(grep tag)`. The fix was already **committed**, so the push stashed nothing. The SHA came back empty, and `git stash apply ""` applied the shared stack's stash@{0}`, another session's 77-line WIP, into my worktree. The "mutation" run also tested the unmutated code and passed, which looked like a broken spec.

**Why:** the stash stack is shared across every worktree, and an empty argument means "latest".

**How to apply:** for mutation checks, don't stash. `cp file $SCRATCH/fixed.rb`, edit the line, run, `cp` back. If you must stash, abort when the captured SHA is empty, and check `git status --short` for files you never touched. Recovery: `git restore <foreign file>`. The foreign stash entry stays intact as long as you don't drop it. Related: [[feedback_verify_new_assertions_can_fail]].
