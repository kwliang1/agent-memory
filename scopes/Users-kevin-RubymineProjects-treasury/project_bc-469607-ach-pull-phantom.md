---
name: bc-469607-ach-pull-phantom
description: "BC run b8f87785 CA 469607 $10k diff → PR #8806 classifies in-flight ACH pulls as pending settlements (Kevin's call, overrode scoping proposal); gate passed; awaiting merge"
metadata: 
  node_type: memory
  type: project
  originSessionId: d406531b-38af-4358-9f93-60ccf5bedc73
  modified: 2026-09-08T20:12:47.415Z
---

Run b8f87785 (2026-09-08), record 231074: CA 469607 treasury $10,000 vs external $0, unexplained. Root cause: AchPull 571386 ($10k, processing, TP pull ach_11n9syjsb63fqtm, scheduled settlement 2026-09-09 09:35 UTC) targets SA 517257 (TP, closed 2026-09-07) but active SA is 517343 (DIBS, activated 2026-09-07) — bank migration mid-pull. `ach_pull_adjustment` (balance_service.rb:113-118) doesn't filter on `ach.sub_account_id`, so it credited the expected DIBS balance $10k the bank never gets. V1 adjustments emit no detail rows → record had details=nil → classifier had nothing to settle → nil resolution.

Ruled out: flipper (ON for 469607, adj_applied=true), PR #8796 provenance removal (details nil, decode never ran).

Kevin's hypothesis (classify in-progress pulls expected-to-settle) refuted in mechanism: the $10k settles into the CLOSED TP sub-account tomorrow, not the checked DIBS account — settling it would mask a real wrong-bank landing (needs sweep after completion). Wires already covered (adjust :134 + classify collector :496).

Proposed (not yet approved): (1) scope ach_pull_adjustment to active-SA pulls (skip when sub_account_id present and != active SA) — blast radius 1 of 527 in-flight included pulls; (2) optionally emit adjusted detail rows for pulls (fixes invisible V1 adjustment, BANK-1557 lineage); (3) no classifier change. Both balance bases (customer_account_balance:35-39 twin) share the term but only touch the balance-check-only method. Classification must stay gated on in_progress_adjustment_applied (classification.rb:28,72,92) — flag-off records mix bases (treasury_amount old basis, details recollected on epb basis, difference_service.rb:232).

Kevin pushed back "funds will be auto forwarded, so expect it to settle" — verified half-right: post-landing, ResolutionService auto-migrates (resolution_service.rb:63-96; Grasshopper Bank Main not in EXCLUDED_PROGRAMS, $10k < $500k threshold, balance_check_auto_heal_inactive_subaccounts flipper ON in prod, runs in-cycle via check_service.rb:142-147) → Window B self-heals. Window A (transit, today's record) still shouldn't settle: TP holds $0 (attempt_resolution! no-oped today), the $10k-on-DIBS assertion is false in every future, and return risk is elevated (settling into an account closed 9-07, R02 possible). Recommendation unchanged: scope the adjustment so Window A mints no record; do NOT emit a classify-only credit row for wrong-SA pulls (contributes $0 to active-SA gap → subset-match could excuse an unrelated break).

Ops: watch $10k landing at closed TP SA 517257 on 2026-09-09; no funds-migration transfer exists for CA 469607 (auto-heal will create one post-landing).

**SHIPPED as PR #8806** (branch kevinliang/balance-check-pending-ach-pull-settlement, commit fa5e62450 signed (amended), pushed 2026-09-08). Kevin rejected the scoping fix, chose: keep the adjustment, emit pull rows, classify as pending settlement. As landed: ach_pull_adjustment emits adjusting credit rows (SLA clock = treasury_prime_scheduled_settlement || initiated_at — an initiated_at clock grades every on-schedule slow pull critical since can_complete_at IS the 3bd buffer); explained_by_pending_ach_pull? settles treasury-ahead gaps subset-summed on adjustment_cents, within-SLA only, whole-set decline on any critical row; past-critical pulls METRIC-ONLY (needs_review would block ResolutionService sweep at resolution_service.rb:26); DD monitor was added then REMOVED per Kevin — detection = ledger-balance-check cron's per-run Slack summary to #banking-alerts (check_service.rb:292-317) + failure threshold (6 fails/7d); payments-health does NOT cover AchPulls (Transfer.pending only, evaluation_service.rb:106-114). Gate: 7 rounds × 5 reviewers, final 2 clean (monitor removal was Kevin's post-gate call, money-safety reviewer's concern accepted as owner risk). Disclosed-not-coded (bounded ≤3bd past settlement + monitored): provisioned-row collision, return-ingestion lag mask, threshold anchor stretch; future tightenings = landed-vs-in-transit provenance flag on rows, settlement-anchored SLA entry. Prod baseline: ~2 records/14d would auto-settle, 0 overdue pulls.

Related: [[balance-check-in-progress-writer-gap]], [[bank1594-incoming-sla]]
