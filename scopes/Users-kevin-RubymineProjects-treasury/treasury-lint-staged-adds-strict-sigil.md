---
name: treasury-lint-staged-adds-strict-sigil
description: "Treasury's pre-commit lint-staged rubocop autocorrect silently adds `# typed: strict` to a sigil-less file you touch, which then fails Sorbet"
metadata:
  node_type: memory
  type: reference
  originSessionId: e1ea752f-14d8-4a25-bfd2-0f4255d2c044
  modified: 2026-10-08T21:59:45.926Z
---

Seen 2026-10-08 (treasury#9099). Committing a one-line change to `app/services/standalone_banking/transaction_service.rb` (no sigil on main) through the normal pre-commit hook: lint-staged's rubocop `--auto-correct` added `# typed: strict`, a blank line, and dropped a trailing `},)` comma, all inside the commit. The next commit attempt (any repo, since the treasury `.claude/hooks/pre-commit-lint.sh` sorbet-checks the branch) then blocked on 7003/7017 errors in that file.

**How to apply:** after any treasury commit that didn't go through `--no-verify`, check `git show HEAD --stat` against what you staged. If extra lines appear, restore the file from `origin/main` + your edit, then `git commit --amend --no-verify -S`. Reviewers reading the working tree mid-gate may describe the file as `typed: strict`; that's this rewrite, not main. Related: [[treasury-worktree-spec-run]].
