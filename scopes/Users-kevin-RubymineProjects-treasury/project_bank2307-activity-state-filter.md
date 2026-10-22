---
name: project_bank2307-activity-state-filter
description: payment_activities.list states filter is raw-state SQL and deliberately ignores the reassigned→Cancelled override; scoped to nova accounts by Kevin
metadata:
  type: project
---

The `payment_activities.list` `states` filter matches on the payment's mapped state in SQL (`PaymentActivities::FetchService.in_states`), not the `DetailsService.state` override that makes a pending row on a no-longer-eligible account read Cancelled.

**Why:** Kevin (2026-10-20) said to design for nova customer accounts, the initial population. In prod none of nova's pending rows diverged from the raw state, so mirroring would copy eligibility logic into SQL. Across all accounts under 0.2% diverge, mostly IncomingWire COMPLETED→CANCELLED; a few rows in unmapped `needs_admin_attention` make `DetailsService` raise, so list already 500s for those accounts. Non-nova accounts have up to ~4k pending rows each, so a Ruby post-filter is too slow.

**How to apply:** if a consumer reports a reassigned/merged row showing under the wrong filter, that is this known gap; re-measure divergence before adding SQL for it. A multi-CA `List::Input` must thread `states` through.
