---
name: Use a worktree when working on a branch other than current
description: When asked to pull down / inspect / modify files from another branch or PR, do it in a git worktree, not by checking out or overwriting files in the main working tree
type: feedback
originSessionId: 744c4a3c-0259-4f65-8971-6a2a659252f9
---
When the user asks to pull down a PR's file, inspect another branch's code, or do work that isn't on the currently-checked-out branch, set up a git worktree and operate there — don't `git checkout` the other branch in the primary working tree, and don't overwrite files on the current branch with content from elsewhere.

**Why:** The user keeps the primary checkout on `main` and expects it to stay clean. Overwriting a tracked file on `main` with another branch's version (even temporarily) shows up as `M` in `git status` and risks an accidental commit on the wrong branch. The user already maintains parallel worktrees (`usvc-usvc-XXX` siblings of the repo, plus `.claude/worktrees/*`) for in-flight work.

**How to apply:**
- Before reading/editing files from another branch, check `git worktree list` — the branch may already have a worktree, in which case enter it via `EnterWorktree` with `path:`.
- If no worktree exists, create one with `git worktree add <path> <branch>` (existing branch) or use `EnterWorktree` with `name:` for a new branch off HEAD.
- Project worktree convention: siblings at `/Users/kevin/RubymineProjects/usvc-<linear-slug>` for branches with PRs; ephemeral ones under `.claude/worktrees/` are also fine.
- Reading another branch's file content read-only (e.g., `git show <ref>:path`) is OK without a worktree — the rule kicks in when you'd otherwise modify the working tree.
