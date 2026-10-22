---
name: feedback_gate_in_fresh_session
description: Gates run after a hydra handoff cost ~3x less main-thread per reviewer than in-place gates — hand off when context is large, and run local checks (tsc/packwerk/lint) once before round 1
metadata:
  type: feedback
---

Measured 2026-10-08 over 132 gate sessions (scripts in `~/agent-memory/scripts/gate-mining/`).
Counting the main thread inside gate windows, plus the context the gate leaves behind for later
turns, reviewers are **~46%** of gate cost, the main thread **~47%**, and the leftover-context tax
**~7%**. The main thread enters a gate at a median of **236k** tokens (p90 688k), and every
orchestration turn re-reads that.

Gates in sessions that arrived by hydra `handoff` started at a median of 139k and cost **2.15 vs
6.90** relative units of main-thread spend per reviewer (46 handoff gates vs 86 in place). Kevin
already does this ad hoc ("handoff the review gates").

**How to apply:**
- Once the diff is committed and the implementation context is over ~150k, offer to hand off
  before round 1. The handoff file carries the branch, HEAD sha, base, the declined-findings list
  with reasons, and the lenses used so far.
- Before round 1, the orchestrator runs the CI-parity checks once and pastes the results into
  every reviewer brief: the full typecheck (and watch for OOM — `tsc` dying read as "0 errors" on
  nova bank-1997 and nova BANK-2057), packwerk, lint on every touched package, and each changed
  spec file. Missed checks that escaped to CI: packwerk (venture bank-2230), tsc (hydra #357),
  `typed: true` (ipseity).
- Reviewers then read results rather than each re-running suites. Re-running is what produced the
  4,000–5,500s outlier reviewers that held whole rounds.

Related: [[feedback_brief_review_agents_with_memory]], [[feedback_handoff_prefix_is_directive]],
[[project_session_token_anatomy]].

**Hand off between rounds, never mid-round (2026-10-14).** The old session's three
round-8 reviewers were spawned ~6 min before the handoff and died with it: transcripts froze at the
handoff timestamp, no findings file was ever written, and the new session waited 7 min on `ls` before
checking `stat` on the subagent transcripts. Either wait for the round's verdicts and record outcomes
first, or write "round N is void, relaunch" in the handoff. The successor can recover the exact
prompts from `~/.claude/projects/<cwd-slug>/<old-session>/subagents/agent-*.jsonl` (first line,
`.message.content`), which is cheaper than re-deriving them from the brief.
