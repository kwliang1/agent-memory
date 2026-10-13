---
name: feedback_gate_round1_mutation_sweep
description: Test-gap resets arrive one surviving mutant per round (~99 in 30 days) — do the full mutation sweep before or in round 1, in an isolated copy, and require a shown kill for every fix-added test
metadata:
  type: feedback
---

Test-gap (F) findings were ~99 of ~520 gate resets in 30 days, and they trickle: the test lens
finds one survivor per round. Treasury Interchange 1679 had six resets that were only test gaps,
each a new survivor; 9140 R7, R8, R9, R13 and R14 were reset only by the test lens. A second
failure: tests added to fix an F were themselves vacuous (bcdb r9, venture BANK-2096 R8,
treasury bank-2150 R3/R5), costing another round each.

**How to apply:**
- Before round 1, or as round 1's test lens, mutate every changed production line and report
  **all** survivors in one list. Close them together.
- Later rounds mutate only the delta since the last round.
- Every test added to close an F needs a demonstrated kill: revert the line, show red, restore.
- Mutate only in a throwaway copy (`git worktree add /tmp/mut-<n> HEAD` or `isolation: "worktree"`),
  never the shared tree — see [[feedback_mutation-agents-corrupt-worktree]].
- Run a touched suite 3× concurrently once; test-only fixes caused shared-DB races (bd0b R11) and
  TMPDIR flakes.

**Why:** a full sweep up front costs one long reviewer; trickling costs a fresh 3-reviewer round per
survivor.

Related: [[feedback_gate_verify_fix_before_next_round]], [[feedback_verify_new_assertions_can_fail]].
