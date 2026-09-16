---
name: feedback-question-the-shared-constant-premise
description: "Before building infrastructure to share a constant across a boundary, check whether the two readers actually represent the same fact — Kevin caught me coupling two rails' settings that merely coincided"
metadata: 
  node_type: memory
  type: feedback
  originSessionId: f47c16b3-3921-4f56-973d-9f74cd90f794
  modified: 2026-07-29T17:58:33.958Z
---

Before adding a module, a `lib/` file, or a packwerk-legal shared home so two packages can read one constant, **first check whether the two readers represent the same fact.** If they're two subsystems' independent settings that happen to hold the same number, sharing the constant asserts they must move together — which is false, and worse than duplication.

**What happened (BANK-1544, treasury, 2026-07-29):** DIBS needed a Piermont IntraFi sweep threshold ($250k). The main app already had `TreasuryPrime::DepositSweep::CreateService::PIERMONT_SWEEP_THRESHOLD = 250_000.to_money`. Packwerk (`enforce_dependencies: strict`) blocks DIBS from reading it, so I built a shared home in app `lib/` and derived both sides from it.

Kevin: *"does this really need its own module? should it be in DIBS?"* then *"can it not live in the enrollmentservice?"*

He was right. `PIERMONT_SWEEP_THRESHOLD` is overwhelmingly **Treasury Prime's own** setting — it feeds TP's sweep API, the eligibility display, and the TP mutation path. Exactly one line uses it as a coarse gate for the DIBS rail, and that predated the PR. Two rails, same FDIC-derived number, no obligation to move together.

Final shape: a plain `PIERMONT_THRESHOLD_BALANCE_CENTS` constant on `DIBS::NetworkBanking::EnrollmentService` (the class that writes it), read by the one other DIBS caller. `PIERMONT_SWEEP_THRESHOLD` left untouched.

**What collapsed once the premise went:** the `lib/` module, a `SWEEP_PREFILTER_FLOOR` constant, and an invariant spec — all of which existed *only* to serve the sharing decision. Diff went 13 files/173 insertions → 12/151, with **zero new production files** (only specs).

**The meta-lesson, and why it matters more than the fix:** eleven rounds of review agents optimized *within* the premise. Round 1 pushed me from a drift-guard spec toward the shared constant; round 7 caught that deriving a cron pre-filter from it endangered Increase's only balance floor. Every one of those findings was correct *given* the premise. None questioned it. Reviewer loops are good at local correctness and bad at "should this exist at all" — so when a human asks "does this need to exist," treat it as the highest-value question in the thread, not a style note.

Also: when Packwerk blocks a read, that's often a signal the concept belongs on one side, not a problem to route around.

Related: [[feedback-concise-recommendations]], [[review-loop-attribution-discipline]].
