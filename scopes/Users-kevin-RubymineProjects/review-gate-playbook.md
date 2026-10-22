---
name: review-gate-playbook
description: Hub for every pre-push review-gate memory — rules, failure modes, and the 2026-10 mining baseline; open this before running or changing a gate
metadata:
  type: feedback
---

The gate itself is in CLAUDE.md, under "Pre-push review gate", steps 0–8. These notes hold the
detail and the evidence behind each step. Repo-specific CI-parity checks live in each repo scope's
`gate-checklist.md`.


**Running a round**
- [the gate is 2 clean rounds, not 3](feedback_review_gate_count.md) — stop at the second "no concerns"; don't add a defensive round.
- [gate stops on FUNCTIONAL feedback only](feedback_review_gate_functional_only.md) — wording and spec-coverage gaps don't reset; fix them, but the round counts CLEAN.
- [declines need evidence](feedback_gate_declines_need_evidence.md) — a declined round is CLEAN; a functional decline needs file:line proof.
- [brief review agents with memory](feedback_brief_review_agents_with_memory.md) — hooks give subagents the code GRAPH but no hook reads `scopes/` at all; paste the notes in, plus diff inline, caller inventory, declines.
- [a review round can die on auth](feedback_review_round_can_die_on_auth.md) — spawned ≠ complete; check each reviewer's last text for `Not logged in` before counting the round.
- [verify a reviewer's negative results](feedback_verify_reviewer_negative_results.md) — "I couldn't exploit it" is a lead, not a verdict; build the exploit yourself.
- [attribution + verify the base](review-loop-attribution-discipline.md) — two rules; `git merge-base`, never a pinned SHA.

**Between rounds**
- [verify the fix before the next round](feedback_gate_verify_fix_before_next_round.md) — fix regressions are ~135 of ~520 resets; sweep the class, and ask Kevin after two B rounds.
- [feedback minimal change in review gate](feedback_minimal-change-in-review-gate.md) — In a review gate, fix only what the finding requires — reaching further introduced 4 regressions in one session
- [feedback freeze tree during review rounds](feedback_freeze_tree_during_review_rounds.md) — Commit and then freeze the tree while pre-push review agents run; editing under them wastes a round
- [round-1 mutation sweep](feedback_gate_round1_mutation_sweep.md) — test gaps trickle one mutant per round; sweep everything up front, in an isolated copy.
- [feedback mutation agents corrupt worktree](feedback_mutation-agents-corrupt-worktree.md) — Review agents doing mutation testing revert/edit source in the SHARED worktree, corrupting the working tree mid-gate
- [serialize mutation agents](feedback-serialize-mutation-agents.md) — or give each its own worktree.

**Before and around the gate**
- [gate in a fresh session](feedback_gate_in_fresh_session.md) — handoff gates cost ~3x less main-thread; run tsc/packwerk/lint once before R1.
- [feedback ai feedback before review gates](feedback_ai_feedback_before_review_gates.md) — Workflow order — address PR AI-bot feedback (Cursor Bugbot, Devin) before running the pre-push review-agent gate
- [gate mining baseline](reference_gate_mining_2026_10.md) — 30-day numbers and scripts; rerun to measure.

**Superseded (kept for history)**
- [feedback review gate reviewer count](feedback_review-gate-five-reviewers.md) — **3** per round as of 2026-09-25 (was 5); CLAUDE.md may still say 5.
- [feedback review gate catches](feedback_review-gate-catches.md) — Review agent settings -- opus model, high effort; address Devin/Cursor feedback; reply to PR threads with fix links
- [feedback buildwt clean round count](feedback_buildwt_clean_round_count.md) — In build-wt spawns, the number Kevin passes is the required count of SUCCESSIVE CLEAN review rounds, not a round ceiling
