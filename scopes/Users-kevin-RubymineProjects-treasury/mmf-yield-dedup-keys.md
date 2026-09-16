---
name: mmf-yield-dedup-keys
description: "MMF yield receipts carry TWO unique dedup keys; the provider-neutral one is a real DB index, and dropping the Frec one loses restatement dedup"
metadata: 
  node_type: memory
  type: reference
  originSessionId: 134e0e7c-dbe0-4de8-9e88-c2263b785ac4
  modified: 2026-09-02T22:53:18.212Z
---

`money_market_fund_yields` has two UNIQUE indexes, both shipped together in #8040 (2026-07-01):

- `index_money_market_fund_yields_on_frec_yield_event_id` — Frec-specific, nullable
- `idx_mmf_yields_on_account_accrued_amount` — `(customer_account_id, accrued_on, amount_cents)`, provider-neutral

`YieldService#receipt_exists?` prefers the frec id when present and falls back to the neutral tuple. `legacy_ledger_entry_exists?` is a third guard on the ledger side, also **account-scoped** (`destination:` / `requester:`), not merely amount+date — do not describe it as amount+date.

**The one thing the frec id buys that the tuple cannot:** a *restated* yield — same Frec event id, same `appliedAt`, different amount — is currently skipped. Without the frec id the neutral key sees a different `amount_cents` and posts a second receipt, double-crediting the customer. `spec/services/money_market_fund_accounts/yield_service_spec.rb` asserts exactly this ("deduplicates on frec_yield_event_id regardless of amount changes"). Whether it can actually happen is a Frec question — unanswered as of 2026-09-02. Everything else about the drop is safe: the neutral index is a genuine DB constraint, so nothing has to be built first.

Deploy ordering for the drop (BANK-1954): code PR removing the writer/reader + `self.ignored_columns` must **deploy** before the migration PR, because migrations run ahead of the code deploy. `safety_assured { remove_column }` is the house pattern.

`Adapters::Base#fetch_yield_events` + the Frec impl have existed since #8071 (2026-07-22); `yield_service.rb` simply never called through them (BANK-1951, `provisioned` scope == `where.not(provider_account_id: nil)`). Related: [[treasury-cron-schedules-cdk8s]], [[treasury-stale-shared-checkout]], [[mmf-sell-fee-skip-regression]].
