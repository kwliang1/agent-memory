---
name: gt modify -a sweeps in untracked files
description: gt modify -a / --all behaves like git add -A and pulls untracked files into the amend; stage by path instead
type: feedback
originSessionId: a27de3e9-1fca-4865-b4a4-583e40cc03f9
---
`gt modify -a` (and `gt modify --all`) is equivalent to `git add -A && git commit --amend`. It will pull untracked files into the amended commit, including scratch scripts, `.claude/` artifacts, and anything else sitting in the working tree.

**Why:** caused a near-miss on the persona-faraday-migration branch — an amend for a one-line review fix swept in `script/bank_alloy_audit.rb`, `script/remove_flippers.rb`, and `.claude/scheduled_tasks.lock`. Caught before push, but only because we re-checked `git show --stat HEAD`.

**How to apply:**
- Before any `gt modify -a`, check `git status` for untracked files; if there are any, stage the intended file(s) by path with `git add <path>` and use `gt modify` (no `-a`) instead.
- Always `git show --stat HEAD` after an amend before pushing — it's the only way to catch this kind of accidental inclusion.
- Same advice as the project CLAUDE.md note about `git add -A` / `git add .` — just applies to the gt equivalent too.
