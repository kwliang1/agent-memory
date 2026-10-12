---
name: reference_nova_forcepush_keeps_approval
description: A force-push to a nova PR branch does NOT dismiss existing approvals (stale-approval dismissal is off)
metadata: 
  node_type: memory
  type: reference
  originSessionId: e9be6599-0ba2-4555-b5f8-9952c11f69ba
  modified: 2026-08-19T23:51:56.572Z
---

On `angellist/nova`, force-pushing to a PR branch (e.g. after amending to address review feedback) does **not** dismiss existing approvals — the "dismiss stale approvals on new commits" branch-protection setting is off. Re-verified 2026-10-01 via `gh api repos/angellist/nova/rules/branches/main`: rulesets 5824624 and 7122204 both have `dismiss_stale_reviews_on_push:false` and `require_last_push_approval:false` (7122204 also has `require_extra_approval_for_unattributed_changes:true`, semantics unverified). Kevin flagged this as a review-bypass hole (approve a 1-liner, push more) — don't present it as a convenience.

**How to apply:** After amending + force-pushing to address review comments, don't tell the reviewer/Kevin they need to re-approve — the approval carries over. CI does re-run on the new commit. Kevin confirmed this on 2026-08-19 (PR #9609). Related: [[feedback_buildwt_clean_round_count]].
