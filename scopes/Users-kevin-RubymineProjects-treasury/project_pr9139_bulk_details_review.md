---
name: project_pr9139_bulk_details_review
description: "treasury #9139 (customer_accounts.bulk_details, Sam, WALLET-508) review state 2026-10-14: Kevin's decisions (no entity auth in treasury, IVC retired for nova, logic in services, fold into details) and the prod fact that 47 nova accounts sit in IVCs, not 1"
metadata:
  type: project
  originSessionId: 6df95c8e-6a45-47e8-828f-c4b8a643b40e
  modified: 2026-10-14
---

Review doc: https://arti.internal.angellist.com/s/review-treasury-9139-bulk-details (v4). Kevin submitted "changes requested" on #9139 from the drafts on 2026-10-14. The decisions are now in the repo via treasury #9160 (`.claude/skills/treasury-prophet-api/SKILL.md`, "Nova-facing endpoints"); read that section before touching `app/handlers/` for nova.

**Kevin's decisions, stated on this review and on #9126 (payment_activities.index):**
- Treasury no longer does per-entity authorization on nova-facing prophet endpoints. "We are leaving authorization up to nova now. Any existing examples are legacy." The INC-4159 blank-entity skip in `find_and_authorize_customer_account!` is legacy too.
- WALKED BACK 2026-10-14 20:03: Kevin first said the IVC/CCA redirect is retired for nova and losing the CCA last-four is acceptable, then deleted that comment before submitting the review once prod showed 47 IVC-linked nova accounts (12 depend on the redirect). Current position: the redirect stays, reuse it on a batch path, do not extend it.
- Batch lookups are business logic: they belong on `CustomerAccounts::InfoService`, not in the handler or the API-contract layer.
- Prefer `index` over `batch`/`bulk` as the batch endpoint name in prophet (#9126 comment).
- `customer_accounts.details` has no caller outside nova (venture only calls `ledger`), so it can become the batch endpoint itself: `ids` only, `entity_id` nilable.

**Prod fact (read console, 2026-10-14):** 3,448 `source='nova'` customer accounts; 0 with nil owner_entity_api_id; 0 with >1 open sub-account; **47 sit in IVC columns across 13 IVCs** (11 full fund setups incl. Partners Fund 2017-2022, Thursday Ventures x2, Capital Factory x2, Aito; 2 CCA-only; 1 MMF). Kevin recalled "1, Sigilwen" — no Sigilwen in the set. Only 4 funds have a CCA sub-account, so the redirect is load-bearing for 12 IVA/disb/escrow accounts.

**Why:** the "FBO shouldn't have an IVC" premise was wrong against the code (fund FBOs do), and the recollection of 1 nova IVC account was wrong against prod. Check both before crediting a premise. See [[verify-domain-premise-before-crediting]], [[feedback_prod-query-local-verify]].

**How to apply:** when reviewing nova-facing treasury endpoints, flag entity auth and IVC resolution as removable, and ask for logic in a service. Rerun `nova_ivc_check.rb` (in session scratchpad; trivial to rewrite: IVC `*_account_id` columns ∩ `CustomerAccount.where(source: 'nova')`) before quoting the 47.
