---
name: sleep-interrupted-test-runs
description: "A long background test run whose wall clock is wildly longer than normal means the laptop slept — the resulting timeout failures are artifacts, not regressions."
metadata: 
  node_type: memory
  type: reference
  originSessionId: c4179225-617f-44e0-8ec4-c9649bf6e18f
  modified: 2026-09-11T05:27:01.253Z
---

A backgrounded suite can report failures caused purely by the machine sleeping mid-run. Seen 2026-09-11 on nova `app`: `npx vitest run` reported `3 failed | 3108 passed` with `Duration 14026s` (~3.9h) for a suite that normally takes ~205s. A clean re-run on the same commit was `326 files / 3111 tests`, zero failures.

**Why:** vitest's per-test timeout is wall-clock. When the process is suspended and resumes, the clock has jumped, so whatever tests were in flight trip their 5s timeout at once. Nothing is wrong with the code.

**The tell is the duration, not the failure count.** Kevin identified it immediately from the wall clock ("the laptop you're running on was asleep") while I had reasoned my way to "resource contention" — wrong cause, and only accidentally the right action. Compare against the suite's known-normal duration before theorising.

**How to apply:** if a long run's duration is an order of magnitude above normal, assume sleep, re-run before investigating, and do not report the failures to Kevin as real until they reproduce. Two independent traps made this worse and are worth avoiding together:

- **Never pipe a suite you intend to call green through `tail`.** I ran `npx vitest run 2>&1 | tail -6`, so the output file held 8 lines: the summary said `3 failed` but the failing file names had scrolled off, leaving nothing to reason about. Same rule as [[nova-worktree-lightweight-verify]] item 9 for lint/typecheck — capture full output.
- **Don't edit files while a suite runs** ([[treasury-never-edit-during-suite-run]]) — it independently fakes failures in unrelated specs, which muddies the diagnosis when sleep is the real cause.
