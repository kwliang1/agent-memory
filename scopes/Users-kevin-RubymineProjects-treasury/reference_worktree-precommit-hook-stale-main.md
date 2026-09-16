---
name: worktree-precommit-hook-stale-main
description: "treasury pre-commit docs-check hook diffs `main...HEAD` using the stale LOCAL main ref — in worktrees it lists hundreds of unrelated files; first commit attempt blocks, second passes via marker"
metadata: 
  node_type: memory
  type: reference
  originSessionId: 0ecebd07-9f46-4482-9c3d-4c1ba9ee4a52
  modified: 2026-09-15T06:35:54.365Z
---

`.claude/hooks/pre-commit-claude-docs-check.sh` computes "files changed on this branch" as `git diff --name-only main...HEAD` against the **local** `main` ref, which in a worktree branched off `origin/main` is usually stale → the hook prints hundreds of unrelated files and BLOCKs the first commit. It touches a marker file so the immediate re-run of the same commit passes.

**`.claude/hooks/pre-commit-lint.sh` has the same stale-`main` bug, and it does NOT have a marker escape hatch — it blocks every attempt.** It builds `RUBY_FILES`/`FRONTEND_FILES` from `git diff --diff-filter=ACMR main`, so a branch off `origin/main` picks up every `.rb` from the commits local `main` is behind by, then runs RuboCop and `make sorbet` over them. Seen 2026-09-14: a one-file `ops/datadog/*.json` change pulled in 25 unrelated Ruby files, and both linters then failed to even *run* — RuboCop on `Bundler::GitError … ipseity is not yet checked out` (no `bundle install` in the worktree) and `make sorbet` on `You have not agreed to the Xcode license agreements` (needs Kevin's `sudo xcodebuild -license`). The hook's Sorbet branch skips on `Bundler::`-matching output but the Xcode error doesn't match, so it blocks.

Diagnose before reaching for a bypass: compare `git rev-parse main` vs `origin/main`, then `git diff --name-only --diff-filter=ACMR origin/main` for the real file list. Fastest real fix is fast-forwarding local `main` (needs a `pull --ff-only` in the main checkout — `git branch -f main` is refused while main is checked out there). Note Biome *does* cover `*.json`, so it is the one linter that genuinely applies to a dashboard-JSON change — run `npx biome check <file>` to show it green.

**How to apply:** don't audit that file list — audit only your real diff (`git diff origin/main...HEAD`) against CLAUDE.md/.claude/skills, then re-run the identical commit command. Also: lint-staged (husky) pushes/pops its own `git stash` backup during commit — expected, it cleans up on success. Related: [[worktree-never-raw-docker-compose]], [[signed-commit-verify-raw-object]].
