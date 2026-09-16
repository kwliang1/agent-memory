---
name: worktree-branch-checkout
description: "Can't checkout a worktree branch in the main checkout — use worktree for testing or cherry-pick to a different branch"
metadata: 
  node_type: memory
  type: feedback
  originSessionId: 3f547bc3-7c80-4584-a0cd-1af36947d35d
---

A branch checked out in a git worktree cannot be checked out in the main checkout (`fatal: already used by worktree`). When suggesting E2E testing, never tell Kevin to checkout a worktree branch in the main checkout.

**Why:** Git enforces one-checkout-per-branch across worktrees. Kevin hit this when trying to test a worktree branch on the main checkout.

**How to apply:** For E2E testing of worktree branches, either: (1) fix the worktree's seed data so the page works there, (2) copy data from the main DB (`treasury_development`) into the worktree DB (`treasury_development_<name>`) via cross-database SQL since they share the same MySQL container, or (3) cherry-pick onto a throwaway branch in the main checkout.
