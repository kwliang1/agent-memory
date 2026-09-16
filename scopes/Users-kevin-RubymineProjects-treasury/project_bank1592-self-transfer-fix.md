---
name: bank1592-self-transfer-fix
description: BANK-1592 funds-migration self-transfer double-count — fixed in PR
metadata: 
  node_type: memory
  type: project
  originSessionId: 892ccf5d-c3ea-4745-9279-94d0bb3f1a41
---

**BANK-1592 shipped as PR #8161** (branch `kevinliang/bank-1592`, commit c9285a9e5, 2026-07-09). Fix: exclude self-transfers (origin==destination==CA) from the from-active partition of `transfer_v2_pending_outgoing_adjustment` (`app/services/customer_accounts/balance_service.rb`); from-elsewhere partition untouched (CA 417372 inbound class). Excluded transfers emit non-adjusting details (adjustment 0, `adjusted` derived as `!zero?`); shared `sla_level_for` helper applies the FUNDS_MIGRATION nil-SLA exemption to ALL three Transfer detail loops (also fixes spurious critical badges on cross-TP-instance chain legs, `transfers/v2/create_service.rb:212-279`); frontend `inProgressAdj` tooltip now renders when detail rows exist at $0 sum.

Key facts for follow-ups:
- **Rollout precondition**: fix is inert until Flipper `:external_payment_processor_balance` is ON for Saronic CA 438551 / Schox CA 438225 ($3.1M ≈ 36% of run clears). Old records auto-resolve via `naturally_resolved` on read.
- **Legacy `customer_account_balance` (:53) still has the bug** — Kevin explicitly chose to leave the control arm alone (2026-07-09).
- Real self-transfer generators: `route_through_svb!` (`outgoing_wires/state_service.rb:750`), `route_to_secondary_account!` (`secondary_account_service.rb:12`); bank-migration `migrate_funds!` self-transfers land in from-elsewhere (created pre-activation).
- `Transfer::ALLOWED_ACCOUNT_TYPES = %w[CustomerAccount]` (transfer.rb:71) — no GlobalAccount origins/destinations on V2.
- Follow-up candidates: 200-row detail truncation cuts $0 explanatory rows first (pre-existing); dedicated stuck-forward monitor (FM legs have no SLA claim anywhere; MonitorJob unaffected).
- Gate: 5 rounds × 5 reviewers; real catches were the frontend tooltip gate (round 1) and the cross-TP-instance FM leg SLA badges (round 2). Related: [[balance-check-destination-credit-fix]], [[balance-check-in-progress-writer-gap]].
