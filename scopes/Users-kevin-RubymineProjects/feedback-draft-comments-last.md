---
name: feedback-draft-comments-last
description: "My code comments overclaim — three review rounds running, the code was right and the sentence describing it was wrong. Write the comment last, against the final code."
metadata: 
  node_type: memory
  type: feedback
  originSessionId: f47c16b3-3921-4f56-973d-9f74cd90f794
  modified: 2026-07-30T01:46:30.114Z
---

**Write code comments LAST, against the final code — not from the intent you started with.** Two independent reviewers flagged the same pattern in me across BANK-1730 (2026-07-29): *"three rounds running where the code was right and the sentence describing it was wrong. You write the comment from the intent, then the intent shifts and the comment doesn't."*

The three, all in one small PR:
1. `# The DIBS-internal class is not nameable from app/ under Packwerk` — **false**. It *is* nameable from `app/public_api/dibs_api` (that package declares `backend/dibs`; it's why the seam compiles). The real constraint is the *root* package. A wrong reason is an invitation to delete the thing it justifies.
2. A correct comment placed **between** rescue clause 1's body and clause 2, so it read as applying only to clauses 2–3 when clause 1 existed for the same reason.
3. `# so every DIBS error enroll! can raise is re-raised as one of these` — **false**, and dangerous: four bare raises downstream (missing tax ID, missing address, two IntraFi rejections) plus `Increase::Client::ApiError` propagate untranslated. A caller trusting "every" would believe a 3-clause rescue covered `enroll!`. Fixed to "…the DIBS errors callers distinguish are re-raised as these; **the rest propagate as-is**."

**Why it matters more than style:** an overclaiming comment is worse than none. It gets *believed*. #3 would have told a future engineer that selective-rescuing three classes covered the method.

A fourth landed in the same PR, and it's the most instructive: `# Root-package callers can't name the DIBS classes under Packwerk`. The *claim* was true — but the stated **mechanism** was wrong. Root code names `DIBS::` constants freely (`DIBS::Client` at `book_transfers/create_service.rb:38`); those constants are simply **owned by the root package** (`app/services/dibs/client.rb`). The real axis is Packwerk **package ownership, not namespace**. A reviewer proved it by dropping a throwaway file in `app/services/` that referenced the constant and running packwerk.

**How to apply:** after the code is final, re-read each comment I added and ask three things — is it literally true of the code as it now stands; does its placement scope it correctly; and **is the mechanism I named the actual mechanism?** Watch for absolutes — *every*, *all*, *never*, *only*, *cannot* — each is falsifiable with one grep. Prefer naming the specific mechanism over a sweeping quantifier, then verify that mechanism too: a *wrong why* is worse than a vague one, because it's what gets a correct guard deleted later by someone who checks the reason and finds it false.

Related: [[feedback-concise-recommendations]], [[review-loop-attribution-discipline]], [[feedback-question-the-shared-constant-premise]].
