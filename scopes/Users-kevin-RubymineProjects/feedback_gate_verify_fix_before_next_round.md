---
name: feedback_gate_verify_fix_before_next_round
description: Fix regressions are the #1 avoidable gate reset (~135 of ~520 in 30 days) — verify your own fix and sweep the defect class before spending a fresh round; two B rounds in a row is a design question for Kevin
metadata:
  type: feedback
---

Mined 2026-10-08 from ~80 gates over 30 days. Reset causes: original-diff bug ~153, **regression
introduced by fixing an earlier finding ~135**, test gap ~99, wording ~93, other ~45. The long
tails are B chains: each fix adds a guard, retry, alarm, or timer, and the next round finds its
hole (hydra Raindrop #358 10 of 16 rounds; nova poll-cadence #9989 R2–R8; treasury BANK-2234
R3–R7, where the R5 advisory lock had a 66-char name — over MySQL's 64 limit, a prod outage).

A second avoidable shape: **same-class bugs found one instance per round** (~25 resets). Nova
bank-1997 R21–23 was the 4th instance of "unknown value renders as clean"; EWA R4 then R6 were the
same `dup` path; bank-2150 R1/R2/R3/R5 were each another entry point.

**How to apply:** before launching the next full round, spawn **one** subagent to do the checks below and
return 3 lines: pass/fail, mutants killed, other instances found. Doing them inline adds 4–8 main turns at
~256k context per round; the subagent keeps main context flat (about 4 cost units/round, break-even at
~15% of rounds prevented).
- Run the suite and typecheck on the fix, and mutation-test the lines the fix added (delete them;
  something must go red).
- When a finding names a class ("this caller doesn't X"), grep for every instance in the diff's
  reach and fix them all at once.
- If a fix adds new mechanism rather than correcting a line, treat it as a design change.
- **Two consecutive rounds dominated by B, or by the same mechanism, means stop and ask Kevin**
  whether to simplify or revert that mechanism. Never auto-push instead: the late real bugs in
  nova bank-1997 R13/R17/R21–23 came after B streaks.

**Why:** fresh rounds are the expensive check; a fix-local check is minutes. The gate still decides
the counter, so this costs no recall.

Related: [[feedback_minimal-change-in-review-gate]], [[feedback_gate_round1_mutation_sweep]],
[[feedback_broaden_review_for_repeat_pattern]], [[reference_gate_mining_2026_10]].
