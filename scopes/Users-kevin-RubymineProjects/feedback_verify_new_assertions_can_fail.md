---
name: feedback_verify_new_assertions_can_fail
description: An added test assertion is not coverage until you show it can fail — mutation-test your own new tests, not just the code
metadata:
  type: feedback
---

After fixing review findings, I added test sections and reported "59 -> 96 assertions" plus eleven
verified mutation kills. A reviewer then showed **three of the new assertions could never fail**, and
five of twelve new guards were untested in both directions.

The causes were all fixture state, not logic:

- An earlier section committed a file with a comma in its path (`app/ach_pulls/odd,name.rb`) and never
  removed it, so every later `seed` refused that concept. A later "two runs produce identical bytes"
  check compared a file the second run never opened.
- A "refuses a linked worktree" check asserted `exit 1` — which the program already returned from that
  same earlier refusal. Deleting the guard left the check green; changing its `die` to `warn` survived
  the whole suite while the program happily wrote from the linked worktree.
- A "belongs to no concept" check named a symbol that could never appear regardless of the guard.

**Why:** the eleven kills I verified were the mutations I set out to kill. I never asked the inverse
question — can each new assertion fail at all? That is the same error as trusting assertion count,
one level up, and it makes a green suite actively misleading because it certifies a guard that isn't
there.

**How to apply:** for every assertion you add, mutate the specific line it is supposed to pin and
confirm *that* assertion turns red — not merely that the suite does. Prefer asserting the effect
(files byte-identical before/after, rows absent from the db) over a proxy like an exit code or a
stderr grep, since a proxy can be satisfied by unrelated state. And check what earlier sections left
in the fixture before asserting on it.

**A mutation that fails to apply is indistinguishable from a passing test.** On 2026-09-29 I
reported "not caught" three times on mutations that had silently not matched — a `%q{}` delimiter
broke on a brace, a heredoc stripped the indentation off the anchor, and a Ruby `sub` replacement
ate a `\1` as a backreference. Each looked exactly like a guard that was already covered. Two of
those "findings" were wrong in the other direction too: I nearly deleted a load-bearing ranking
tier because a stale copy of the mutant said it changed nothing. Make every mutation script
`abort` unless it matched exactly once, and for a "does X matter" question diff against a **fresh**
copy of the real branch rather than a mutant you built earlier.
**And the harness must run every suite the naming assertion lives in.** On 2026-09-29 a
mutation harness ran two of the repo's six suites; every mutation whose assertion lived in a third
suite reported *** NOTHING FAILED *** and read as a coverage hole that was not there. The inverse
also bit: a mutation whose replacement text referenced a variable a later round had renamed threw a
ReferenceError instead of making the one change it named, so it was "caught" by the wrong
assertions. Re-read a mutation's `to:` text after any rename.

Related: [[feedback_minimal-change-in-review-gate]], [[feedback_review-gate-catches]],
[[feedback_freeze_tree_during_review_rounds]].
