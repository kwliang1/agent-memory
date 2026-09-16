---
name: mmf-balance-check-multiprovider
description: "MMF balance-check monitoring (BANK-1486, PR #8067) generalized to multiple concurrent providers; the coherence axis + the one deferred APEX follow-up."
metadata: 
  node_type: memory
  type: project
  originSessionId: 1cd89fee-2b4c-45e5-8610-07dd8d8fe292
  modified: 2026-07-31T00:28:37.168Z
---

PR #8067 (BANK-1486, branch `kevinliang/bank-1486-v2`) monitors MMF balance divergence via the 8h `ledger:balance_check` cron. Generalized off the single-Frec assumption + a second review batch (commit `2d487adcd`).

**The coherence axis (why the generalization is shaped this way):** three decision points must key off the SAME axis or an enumerated sub-account falls through to `SubAccounts::BalanceService.external_balance`'s `raise 'Non TP/DIBS/MMF sub account…'`:
1. enumeration — `CheckService#money_market_fund_sub_account_ids`
2. branch selection — `DifferenceService` `sub_account.money_market_fund?` (internal = `net_liquidation_value`)
3. external-balance routing — `SubAccounts::BalanceService.external_balance` → `MoneyMarketFund::Adapters::Base.for(ca).external_total_equity`

Axis = `PartnerBank::Program::MONEY_MARKET_FUND_PROGRAM_NAMES` (a SET, one program per provider; `money_market_fund?` = set membership). NOT the provider binding — the binding is provider-agnostic but the branch/routing gate on the program predicate, so program-name-set is the coherent axis. Also splatted into `ResolutionService::EXCLUDED_PROGRAMS` (MMF accounts have no inactive-SA cash to auto-heal). Adding APEX = append its program name + a `Provider` enum value + a `when` in `Adapters::Base.resolve_adapter_class` (`T.absurd` makes it compile-checked). Provisioning/transfer/yield paths stay Frec-specific on the singular `MONEY_MARKET_FUND_PROGRAM_NAME`.

**Metric (shipped in the review batch — Kevin wanted it now, not deferred):** NO bespoke `mmf_divergence.*` metric. MMF folds into the existing `treasury.customer_accounts.balance_check.{failed,errored}` gauge with a **`check_account_type:bank|mmf`** dimension (Kevin named it `check_account_type`, not `check_type`) + a `provider:` dim for mmf, derived registry-free via `sub_account.customer_account.money_market_fund_provider&.provider&.serialize` and emitted per-provider (`group_by`). Bank series = threshold count (`accounts_surpassed_threshold`, always emitted); MMF series = raw per-provider count, sparse (emitted only when >0 — fine: monitors are `notify_no_data:false` + `>2` + `max(last_10h)`). **Bank threshold query MUST exclude MMF** (`failed_accounts.reject(&:money_market_fund?)`) or a repeatedly-diverging MMF account double-counts into `check_account_type:bank` (a review agent caught this after two missed it). Monitors query `{check_account_type:mmf} by {provider} > 2`; 3 banking.json widgets filter `check_account_type:bank`. `Treasury::Statsd.base_tags` was REMOVED — the DD agent injects env/kube via unified service tagging; ~0/83 treasury emissions tag them manually.

**Real remaining follow-up:** order-based **auto-classification** of settling-MMF divergences. `net_liquidation_value = balance(settled) + position_balance`, and `position_balance` counts only SETTLED ledger legs (`pending_sell_position_hold` holds pending) — so a settling `MMF::Buy/Sell` (which IS a Transfer) transiently diverges NLV-vs-external until its ledger leg posts. The cash-transfer in-progress machinery (`DifferenceService#collect_in_progress_metadata!`) genuinely doesn't model orders, so the skip stays + comments corrected; classifying order-explained divergences as expected-to-settle (vs paging) is the follow-up left for Kevin's call.

Enumeration uses scopes: `SubAccount.money_market_fund` + `AccountProvider::MoneyMarketFund.provisioned` (RBIs regenerated). Casts swept to `sub_account.customer_account` (typed accessor, raises on non-CA) — kept polymorphic `.account` only where GlobalAccount is reachable (`record_type#current_external_amount` else-branch, Flipper actor, `.is_a?(GlobalAccount)`).

See [[mmf-design-doc-arti]] for the adapter seam + APEX project (BANK-1669..1693).
