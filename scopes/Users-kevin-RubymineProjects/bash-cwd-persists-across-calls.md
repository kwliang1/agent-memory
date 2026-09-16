---
name: bash-cwd-persists-across-calls
description: "Bash tool cwd persists between calls — a single `cd` to a shared checkout silently redirects later git/spec commands out of the worktree"
metadata:
  node_type: memory
  type: feedback
  originSessionId: e3448b36-e106-4f90-a3aa-a714e6b90df8
  modified: 2026-07-28T06:35:33.352Z
---

The Bash tool's working directory **persists across calls**. One `cd` for an unrelated reason redirects every later relative-path command — including `git commit --amend` and `docker compose ... rspec`.

**How it bit (2026-07-27, BANK-1710):** working in worktree `.worktrees/treasury-moss`, I ran `cd /Users/kevin/RubymineProjects/treasury && al console exec ...` to attempt a prod query. Never cd'd back. The next two commands ran in the **shared main checkout**:
- `bundle exec rspec` reported "1276 examples, 0 failures" — against *main's* code, not my branch. A false green (the real number from the worktree was 1294). This is the dangerous part: the run looks like verification but verifies nothing.
- `git add -A && git commit --amend` rewrote **another session's commit** on local `main` (`7723d5191` "add DisplayInterface to OutgoingPaymentType (#8372)") with my commit message.

**Recovery:** harmless because `git add -A` staged nothing (that tree was clean), so the new commit's tree was *identical* — verify with `git rev-parse <bad>^{tree} <good>^{tree}` before choosing a reset mode, then `git reset --soft <good-sha>` (soft, so any other session's staged work survives). Nothing had been pushed. My worktree branch was untouched.

**How to apply:** never rely on inherited cwd for git or test commands. Use `git -C <abs-path>` always, and for compose `cd <worktree> && ... ` *inside the same command* with `echo "PWD=$(pwd) BRANCH=$(git branch --show-current)"` as a guard so the output proves where it ran. Treasury worktrees also need `TREASURY_WORKTREE_NAME=<name>` (the Makefile derives it from the dir basename, so raw `docker compose` misses it).

Related: [[shared-checkout-worktree-isolation]], [[treasury-worktree-dev-loop]], [[graphite-prepush-commits-staged]].
