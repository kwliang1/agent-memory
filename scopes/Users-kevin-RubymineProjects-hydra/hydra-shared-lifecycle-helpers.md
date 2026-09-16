---
name: hydra-shared-lifecycle-helpers
description: hydra session-lifecycle helpers (tryResume/doSpawnSession/killSession) are shared by manual thread commands AND auto-recovery — changing one silently alters the other
metadata: 
  node_type: memory
  type: feedback
  originSessionId: 8a8e954f-a60f-4b2e-950f-8302f1638176
  modified: 2026-08-22T18:18:44.925Z
---

In hydra, the session-lifecycle helpers `tryResume`, `tryRespawn`, `doSpawnSession`, and `killSession` (`daemon/session-lifecycle.ts`) are shared between the **manual thread commands** in `daemon/commands/thread.ts` (`resume`/`respawn`, `handleResumeIntercept`) and **daemon auto-recovery** in `daemon/commands/global.ts` (`recoverOne`). A change made for one caller silently changes the other.

Concretely (caught in the post-reboot-recovery PR review): making `tryResume` unconditionally `preserveWorktree: true` for recovery also changed manual `resume` — which has no reattach pre-flight — so a gone worktree dir made `doSpawnSession` throw, degrading resume to fork/respawn and orphaning the branch. Fix was to gate the new behavior behind a `preserveWorktree` flag only `recoverOne` passes; manual `resume` stayed byte-identical to main.

**Why:** these helpers look like private recovery plumbing but are a shared API surface; the manual path and the recovery path have different pre-conditions (recovery pre-resolves the worktree, manual does not).

**How to apply:** when editing any of these helpers, grep every caller first (`grep -rn tryResume daemon/ cli/`). Gate new recovery-only behavior behind a flag the recovery caller sets, and verify the manual command's behavior is unchanged (`git diff main` on the caller in thread.ts should stay empty). This also keeps the change within hydra's one-concern-per-PR rule. See [[hydra-reboot-recovery-facts]] and [[hydra-worktree-name-divergence]].
