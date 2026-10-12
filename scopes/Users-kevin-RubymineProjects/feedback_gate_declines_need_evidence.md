---
name: feedback_gate_declines_need_evidence
description: Rule 7 fails both ways — declined findings were miscounted as resets (5×), and declines without evidence let real bugs ship (06ab R6, 9140 3/6 overturned); a functional decline needs file:line proof and goes to the next domain lens
metadata:
  type: feedback
---

Two opposite failures in 30 days of gates:

- **Declines miscounted as resets.** Nova #10607 R3 and R7, treasury #9018 T5, bank-2150 R17. Kevin
  had to say "no it shouldn't reset the count if you decline it." A round whose only feedback is
  a declined finding is CLEAN.
- **Declines that were wrong.** Treasury no-EIN wires R6 declined the `provision_and_submit!` gap,
  pushed, and Bugbot flagged the same gap: 8 more rounds. On 9140 a stress test overturned 3 of 6
  declines. On venture BANK-2096 a human later proved right a finding declined three times.

**How to apply:**
- A functional decline needs a file:line or a command output that refutes it, not argument.
- List every decline with its evidence in each later brief. Ask the next round's domain lens to
  rebut it if the evidence is weak, rather than telling reviewers "do not re-raise".
- Wording-only declines need no evidence; see [[feedback_review_gate_functional_only]].
- Before acting on a reviewer's "showstopper", reproduce its premise. Unverified premises drove
  hydra #357 R3 (the fix leaked a write key) and treasury bank-2143 r2→r3 (two false copy claims applied).

Related: [[feedback-declined-finding-does-not-reset-gate]] (nova scope), [[feedback_verify_reviewer_negative_results]], [[feedback_review_gate_count]].
