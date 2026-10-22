---
name: worktree-container-has-no-git
description: Inside a worktree's app container git is unavailable, so `git checkout <file>` silently fails to revert a mutant
metadata:
  type: feedback
---

A worktree's `.git` is a file pointing at `~/RubymineProjects/treasury/.git/worktrees/<name>`, a host path the container can't see. Any `git` inside `docker compose ... run app` prints `fatal: not a git repository`, and a trailing `; true` hides it. On 2026-10-20 (BANK-2308) a mutant sed'd into `details_service.rb` stayed in the working tree after an in-container `git checkout` "revert".

**Why:** an unreverted mutant gets committed or pushed while the specs look green.

**How to apply:** when you mutation-test in the container, snapshot the file first (`cp $F /tmp/orig.rb`), restore with `cp`, and then `diff` against a host-side copy before committing. Related: [[treasury-worktree-dev-loop]], [[gate-checklist]].
