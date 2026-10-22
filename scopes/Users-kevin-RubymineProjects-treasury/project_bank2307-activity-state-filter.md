---
name: project_bank2307-activity-state-filter
description: BANK-2307 payment_activities.list states filter — raw-state SQL, deliberately ignores the reassigned→Cancelled override; scoped to nova accounts by Kevin
metadata:
  type: project
---

`payment_activities.list` `states` filter (treasury#9204) matches on the payment's mapped state in SQL (`PaymentActivities::FetchService.in_states`), not the `DetailsService.state` override that makes a pending row on a no-longer-eligible account read Cancelled.

**Why:** Kevin (2026-10-20) said to design for nova customer accounts, the initial population. Prod 2026-10-20: 0 of 2,790 nova pending rows diverge from the raw state; mirroring would copy eligibility logic into SQL. All accounts (same day): 184 of 105,181 pending rows diverge — 178 IncomingWire COMPLETED→CANCELLED, 3 AchPull, 3 QueuedTransfer in unmapped `needs_admin_attention` (DetailsService raises, so list already 500s for those accounts), 1 dangling IncomingWire. Non-nova accounts have up to ~4k pending rows each, so a Ruby post-filter is too slow.

**How to apply:** if a consumer reports a reassigned/merged row showing under the wrong filter, that is this known gap; re-measure divergence before adding SQL for it. #9183 (multi-CA List::Input) must thread `states` through.
