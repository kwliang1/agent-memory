---
name: project_bank1511-mmf-dry-refactor
description: "BANK-1511 PR #8370 — MMF DRY refactor (provider-binding readers + activity error-log dedup); 2 of 4 ticket items obsolete; uuid-in-metadata + in-flight drain shim."
metadata: 
  node_type: memory
  type: project
  originSessionId: 23b68fa9-be75-423c-be38-7d8010b45530
  modified: 2026-07-27T23:04:53.418Z
---

BANK-1511 ("DRY up MMF provider-binding lookups…") shipped as PR **#8370** (branch `kevinliang/bank-1511`, off `main`). Verify-before-build found **2 of 4 items obsolete**: the `provider_for`/`handle_terminal_transition!` extractions targeted the legacy `MoneyMarketFundAccounts::CreateService` write path + refresh cron, both **deleted by #7973 (BANK-1505) and #7974 (BANK-1467)**. Terminal-transition logic now lives thinner in `Applications::MoneyMarketFunds::RefreshService`.

Shipped (the 2 live items):
- **Item 3** — canonical `MoneyMarketFundAccounts::InfoService.provider_account_id!` (FREC id) / `provider_payment_id!` (wire-memo number); `OrderService` (sell!, get_frec_deposits — removed private `frec_account_id_for`), `Statements::FetchService`, and `wire_memo_info` all route through them → one consistent error message.
- **Item 4** — `RegisterDepositAccountsActivity` dropped its duplicate `Rails.logger.error` (Sentry dedup was already done in #7944). `TemporalUtils::Interceptors::ErrorLogger` now folds **scalar** activity args into error metadata and **redacts non-scalars** — this closes a real PII gap: `PublishEntityAttributeValueActivity` passes entity address components (`city/state/country/postal`) as `values: T::Array[String]`, which a naive `input.args` fold would have pushed to Sentry. Interceptor is shared across all ~32 Temporal+DIBS activities.

Per Kevin: put the **uuid, not the int id**, in failure metadata — did it by switching the workflow/activity/starter arg to `application.uuid` + keying `workflow_id` on it (uuid kept OFF STATSD tags = cardinality). In-flight drain handled by a transitional `is_a?(Integer) ? find_by(id:) : find_by(uuid:)` shim + widened sigs (see [[reference_temporal-sig-widen-inflight-drain]] — the one real bug the review gate caught).

**Status:** fully green after rebase-on-main (commit `871257aaf`) — all 22 CI checks incl. all 4 rspec shards, Cursor Bugbot + depthfirst both pass; awaiting human review. Initial `rspec-treasury-1` red was a KnapsackPro dynamic-sharding collision with the unrelated `recreate_legacy_mmf_ct_orders_task_spec`, cleared by rebase (see [[reference_treasury-knapsack-queue-mode]]) — zero coupling; my change is 200+ examples green locally.

**Deploy note (Kevin asked):** no need to confirm zero pending MMF applications first — the transitional shim (both sigs `T.any(String, Integer)` + dual `find_by(id:)`/`find_by(uuid:)`) drains in-flight int-id workflows cleanly on replay.

**Follow-up to file:** drop the transitional int branch + narrow both `execute` sigs to `String` once in-flight register-deposit workflows drain. Drain-window duplicate registration is benign — `Frec#register_deposit_accounts!` dedups by routing last-4, and `provision!` only re-fires for a still-`Pending` application.
