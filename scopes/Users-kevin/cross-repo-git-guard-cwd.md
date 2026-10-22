---
name: cross-repo-git-guard-cwd
description: When a session's cwd is one repo but git work happens in another worktree, guard every git-writing command with set -e and an explicit branch check
metadata:
  type: feedback
---

Bash resets cwd to the session's primary worktree after every call. On 2026-10-21 a chain `ls missing && cd venture && ... ; git commit --amend` failed at `ls`, skipped the `cd`, and amended the *treasury* branch instead of venture (tree unchanged, restored with `git reset --keep`).

**Why:** `;` after a failed `&&` chain keeps running in the default cwd, and commit hooks/signing make the wrong-repo amend look successful.

**How to apply:** for any git-writing command in a non-primary repo, start with `set -e; cd <abs path>; [ "$(git branch --show-current)" = <expected> ]`, or use `git -C <abs path>`. Never mix `&&` and `;` before a commit/amend/push.
