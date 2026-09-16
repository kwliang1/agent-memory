---
name: hydra-worktree-name-divergence
description: "hydra recovered/resumed sessions get a FRESH tmuxName but keep their ORIGINAL worktreeBranch — so name and branch diverge; branch-protection must parse worktreeBranch, never tmuxName"
metadata: 
  node_type: memory
  type: project
  originSessionId: 8a8e954f-a60f-4b2e-950f-8302f1638176
  modified: 2026-08-22T18:18:54.859Z
---

In hydra, when a dead session is recovered/resumed, `doSpawnSession` picks a **fresh** `tmuxName` (via `pickSessionName`) but persists the **preserved original** `worktreeBranch` (`wt/<original>`). So after the first recovery, `tmuxName` and `worktreeBranch` **diverge** (e.g. `tmuxName="nova"`, `worktreeBranch="wt/bar"`), and they diverge again every subsequent reboot-recovery.

Consequence (real data-loss bug caught in review): any logic that protects the preserved branch from a concurrent `createWorktree` stale-cleanup `git branch -D wt/<name>` must derive the base name from **`worktreeBranch`**, not from `tmuxName`. `pickSessionName` already parses `s.worktreeBranch.slice(3).split('-')[0]` (`daemon/sessions.ts`), and `recoverOne`'s in-flight `reservedNames` reservation must do the same — reserving `deadInfo.tmuxName` protects the wrong token once diverged, leaving the real branch base pickable during the multi-second kill→persist window.

**Why:** the tmux session name and the git worktree branch are independent identities that happen to coincide only on a session's first life; the branch (and its unpushed commits) is the thing worth protecting, so branch identity is authoritative.

**How to apply:** for any name-collision guard, reservation, or `branch -D` avoidance in the recovery/worktree code, key off the worktree branch base (`branch.slice(3).split('-')[0]` when it starts with `wt/`), matching `pickSessionName`. Never assume `wt/<tmuxName>` === the preserved branch. See [[hydra-reboot-recovery-facts]] and [[hydra-shared-lifecycle-helpers]].
