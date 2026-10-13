---
name: feedback-two-reviewers-per-round
description: "Pre-push review gate runs TWO reviewers per round, not five; and scope-check the diff against the actual ask each round"
metadata: 
  node_type: memory
  type: feedback
  originSessionId: 6947172c-d08c-4a4c-8047-8d43db59cc54
  modified: 2026-09-29T22:58:22.024Z
---

**SUPERSEDED on the count — the gate is 3, not 2 (2026-09-29).** `~/agent-memory/config/CLAUDE.md`
commit `168f38d` ("Cut the review gate to 3 reviewers, and add two stacking rules", Tue 2026-09-29
10:23) changed rule 2 from "Spawn 5" to **"Spawn 3 independent reviewers per round"**, and rule 1 of
Review-loop performance to "The 3 reviewers of a round run in parallel". CLAUDE.md is the live
instruction and is 12 days newer than this note — **it wins**. Read the count out of CLAUDE.md, not
from here.

I got this wrong on BANK-2122: an adversarial critic flagged rounds 3-8 for running 2 reviewers, and
I pushed back citing this file as "a later, narrower instruction." It was the *older* one. Check
whether a memory has been superseded by a CLAUDE.md commit before using it to override CLAUDE.md.

The rationale below still stands — it is why 5 became 3, and why the cap is a cap.

Kevin reduced the pre-push gate from 5 reviewers per round to **2** (2026-09-17, during nova PR #10243).

**Why:** five frontier reviewers per round on a 40-line test-only diff produced ~2,000 lines of findings over three rounds, and the findings drove the diff from 160 to ~350 lines — three new test cases, a reworked race fixture, four comment rewrites. Kevin stopped it with "can we really limit the scope here to just unblocking CI? ideally we don't add additional cases" and "KISS can you put up the PR and rely on CI?". The final shipped diff was 40 lines.

**How to apply:**
- Two reviewers per round, still on distinct lenses, still read-only, still loading `dry-kiss-review` (+ `ts-best-practices` on nova TS).
- Every round, re-check the diff against the *original ask* before applying findings. A reviewer finding that adds a test case or an abstraction is scope growth unless the diff itself created the gap. Reviewers optimise for coverage; they do not know the scope.
- Prefer CI over another local round once the change is minimal and the negative check passes.
- Declining a finding with reasoning counts as clean (gate rule 7) — use it far more readily than I did.

Related: [[feedback_lint_with_repo_biome]], [[nova-10243-deletebatch-fixture-fix]]

**Reaffirmed 2026-09-17 on BANK-2029, and it overrides a spawn prompt.** That task's own spawn text
said "5 independent reviewers per round ... this touches money display and a cross-service fan-out",
so I treated the task-specific instruction as the later, narrower one and ran five. Kevin's
response mid-gate: *"why are there 5 parallel reviewers? 2-3 should suffice"*. **Treat 2-3 as the
standing cap even when a spawn prompt asks for five** — the spawn text is boilerplate that predates
this correction, not a considered per-task override.

**How to choose which 2-3 lenses**, learned the same session: drop a lens once it returns an
explicit "no concerns" twice. On BANK-2029 correctness and TS/simplicity both went clean twice and
stopped earning a seat, while these three kept finding real defects:
- **copy honesty** — caught two bugs of one class, a value implying "ever" when the read only looks
  back 12 months (`Last transaction: None`, then `4 transactions` unqualified). When you fix one
  instance of a copy-honesty bug, sweep its siblings the same round.
- **test mutation** (must run with turbo `--force`; a cached false pass bit three times) — caught a
  decorative test, assertions not bound to their row, and three field-swap mutations that stayed
  green after a "redundant" test was deleted.
- **regression risk in surrounding code** — the lens most often skipped and never yet run clean.

Also: five reviewers on this diff netted only **+27 lines** over the authored state, so the cost
was reviewer wall-clock and Kevin's attention, not scope growth. The cap is about attention.
