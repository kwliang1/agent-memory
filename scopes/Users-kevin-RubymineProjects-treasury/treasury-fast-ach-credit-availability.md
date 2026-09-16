---
name: treasury-fast-ach-credit-availability
description: ACH-pull accelerated funds availability — gated on EAA reliability + $25k global cap; the $10M trusted seed is clamped/inert.
metadata: 
  node_type: memory
  type: reference
  originSessionId: 9b80b9f7-35a6-469a-a002-bd0105a6b2cb
  modified: 2026-08-03T21:52:02.472Z
---

Treasury "accelerates funds availability in certain circumstances" for ACH-originated debits = **fast ACH credit**. `AchPull#can_complete_at` (`ach_pull.rb:280`): if `eaa.reliable? && amount <= eaa.max_fast_ach_pull_amount` → credit immediately (`initiated_at`); else hold `ReviewReason::ACH_PULL_SETTLEMENT_BUFFER_DAYS = 3.business_days` (`review_reason.rb:28`). Credit = the `LedgerEntry` in `ach_pulls/state_service.rb:139`, gated by `can_complete?` at line 128.

Two gates for acceleration:
1. `reliable?` state — `meets_reliability_criteria?`: ≥2 completed pulls (`MIN_COMPLETED_ACH_PULLS_FOR_RELIABILITY=2`) & not RejectionService-flagged, OR `manually_marked_reliable`.
2. amount ≤ `max_fast_ach_pull_amount` (`external_ach_account.rb:325`) = `min( max(1.5×largest_completed_pull, initial_max_fast_ach_pull_amount), GLOBAL_MAX_FAST_ACH_PULL_AMOUNT=$25k )`.

**GOTCHA (Kevin flagged 2026-08-03):** `TRUSTED_ACCOUNT_MAX_FAST_ACH_PULL_AMOUNT = 10_000_000.to_money` ($10M, IVC.rb:81) is seeded as `initial_max_fast_ach_pull_amount` but is **inert** — the final `.min` with the $25k global caps everyone. No pull ever fast-credits above **$25k**. The $10M seed only lets a trusted account reach the $25k ceiling on pull #1 instead of growing into it via 1.5×history. Operative cap = $25k, NOT $10M.

The 3-day buffer also powers the outgoing-withdrawal fraud gate `ReviewReason::PENDING_ACH_PULL_SETTLEMENT` (`review_reason.rb:147`, `fraud_prevention/compliance_rules_service.rb:272`) — blocks withdrawing funds dependent on a not-yet-settled pull until settlement + 3 business days. Relates to [[incoming-wire-return-automation-gap]].

Note: $1M is the NACHA *Same Day ACH* per-txn network cap — separate concept from our internal pre-settlement credit cap.
