---
name: ipseity-srb-tc-scans-untracked-dirs
description: srb tc in the ipseity main checkout also typechecks untracked .claude/, ipseity-worktrees/ and .worktrees/; pass --ignore for each
metadata:
  type: reference
---

`sorbet/config` runs with `--dir .` and ignores only vendor, db, spec and a few others. The main checkout carries untracked `.claude/`, `ipseity-worktrees/` and `.worktrees/` directories, and Sorbet reads them: errors and duplicate definitions from other branches show up as yours. `.gitignore` doesn't help, because Sorbet doesn't read it.

**How to apply:** in the main checkout, run `bundle exec srb tc --ignore=/.claude --ignore=/ipseity-worktrees --ignore=/.worktrees`. A clean worktree doesn't need the flags. Stage by path, never `git add -A`, for the same reason.
