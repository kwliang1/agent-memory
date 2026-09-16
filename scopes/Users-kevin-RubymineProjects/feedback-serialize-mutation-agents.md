---
name: feedback-serialize-mutation-agents
description: "Run mutation-testing review agents one at a time — parallel agents on one worktree edit the same files and can clobber each other's restores"
metadata: 
  node_type: memory
  type: feedback
  originSessionId: f523bd46-f46b-441f-a99c-4a3ab16700de
  modified: 2026-07-30T23:11:59.335Z
---

Review agents that **mutation-test** (delete a guard, re-run specs, restore) must be run **serialized**, not in parallel, when they share a worktree.

**Why:** during PR #8416's review gate I ran two mutation-testing agents concurrently on `.worktrees/treasury-bai2-458`. They edited the same file simultaneously. I caught the tree mid-mutation with `nil` substituted for a real guard, and one agent reported a spurious `114 examples, 2 failures` caused by the *other* agent's in-flight mutant. Each agent restores from its own snapshot, so a `git checkout` race can silently revert real branch work.

**How to apply:** parallel agents are still right for *read-only* review lenses (correctness / ops / test-quality reading the diff). The moment an agent is told it may mutate files, run it alone — or give it its own worktree. Either way, snapshot `git diff` to a scratchpad file first (`known-good-<round>.diff`); it applies against HEAD, so restoration is guaranteed no matter how an agent leaves things. Verify with `diff` against that snapshot plus `git status --porcelain` before committing, and check for stray untracked probe specs — one agent left a `zz_*_probe_spec.rb` behind.

Related: [[review-loop-attribution-discipline]], [[shared-checkout-worktree-isolation]].
