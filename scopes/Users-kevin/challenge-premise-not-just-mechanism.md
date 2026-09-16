---
name: challenge-premise-not-just-mechanism
description: "In RCA (esp. money-movement), challenge WHY an operation runs before validating HOW it fails; a blocking validation error may be a guardrail, not the bug"
metadata: 
  node_type: memory
  type: feedback
  originSessionId: 69d8b83c-f3ea-4100-88e0-384fe2bcfb76
  modified: 2026-08-20T00:41:53.933Z
---

When root-causing an exception, first ask **"should this operation be happening at all?"** — challenge the premise — *before* validating the mechanism of the failure. A validation error that blocks a harmful action can be an **accidental guardrail**, not a bug to remove.

**Why:** On 2026-08-19 a treasury BAI2 file failed with "CustomerAccount 465829 insufficient balance" while trying to *return* a $1.8M wire. The RCA worker and I both correctly traced the mechanism (an earmark/ordering bug: `return!` reverses the funding plan before the Rejected transition releases the earmark, so available balance is $0) and endorsed a "reject-first" reorder as de-risked and ready. **Kevin challenged the premise** — "why are we returning? the wire is sending funds *out*" — and was right. There was no returned wire: the $1.8M was our OWN incoming funds-migration wire (FTB FBO → SVB disbursement acct) arriving to *fund* the outbound payment, misclassified as a return by an **amount-only** matcher (`wire_processing_service.rb:284-303`). The reject-first "fix" would have *removed the guardrail* → wrongly Rejected a live $1.8M payment, clawed back its funding, and fired a Failed event to Venture. The insufficient-balance error was the only thing preventing that. Real fix was at classification (exclude self-FBO/internal-migration credits), not the reversal path.

**How to apply:** Before endorsing any fix to a money-movement failure: (1) state what the operation is *supposed* to accomplish and confirm the inputs actually warrant it (here: is this genuinely a returned wire? whose bank did it come from?); (2) treat a blocking validation/balance error as a possible safety net — ask what bad thing it's preventing before "fixing" it away; (3) don't let a clean, well-evidenced *mechanism* trace lull you — a correct mechanism explanation of a wrong premise is still wrong. This is the fact-based-adversary rule aimed at the premise, not just the trace. See [[verify-fleet-state-not-assume]].
