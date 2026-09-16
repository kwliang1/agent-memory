---
name: worktree-paths
description: Always use worktree root for file paths when working in a worktree environment
type: feedback
---

When working in a worktree (e.g. `.worktrees/great-blackburn/`), always reference files from the worktree root, not the main repo root. For example, use `/Users/kevin/RubymineProjects/nova/.worktrees/great-blackburn/graph/src/...` not `/Users/kevin/RubymineProjects/nova/graph/src/...`. The worktree is an isolated copy of the repo.
