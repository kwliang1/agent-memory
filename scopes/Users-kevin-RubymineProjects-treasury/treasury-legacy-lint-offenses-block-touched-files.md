---
name: treasury-legacy-lint-offenses-block-touched-files
description: Since treasury #9317/#9406 (10/29, 11/3 2026), error-level cops plus rubocop_changed_files and lint-staged mean any PR touching a file with legacy offenses goes red and cannot even commit locally; check sf8193's lint stack before fixing it yourself
metadata:
  type: project
---

`Sorbet/ForbidTUntyped`, `Treasury/ForbidTAnything`, `Angellist/ClassStructure`, `Style/ClassMethodsDefinitions` and `Naming/PredicateMethod` are error-level in treasury. CI runs `bin/ci/rubocop_changed_files.sh` on every file a PR touches and lint-staged runs the same gate on staged files, so a one-line edit to a legacy file fails CI and refuses the commit (BANK-1803 on 2026-11-03: transfer.rb 13, funding.rb 4, Interchange adapter 1, all main's own lines).

**Why:** the cops landed on main after the branch was cut; a rebase alone turned a clean PR red.

**How to apply:** before fixing legacy offenses yourself, list sf8193's open `chore(lint)` PRs (`gh pr list --search "chore(lint)"`) and run the CI script against their heads (`git fetch origin pull/<n>/head:refs/pr/<n>`, detached worktree, borrowed container). On 11/3, #9412 cleared transfer.rb and the adapter the same afternoon; only funding.rb needed a base PR (#9440), and Kevin's call was a base PR, not folding it in. If a commit must carry a verified fix past lint-staged because of someone else's legacy lines, `--no-verify` is lint-staged only, signing still runs; say so in the thread. See [[gh-stack-adopts-existing-prs]].
