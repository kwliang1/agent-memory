---
name: treasury-prophet-ledger-consumed-by-nova
description: "Treasury's paginated Prophet CustomerAccount::Ledger endpoint is consumed by NOVA (not just venture/ACE) — Kevin corrected this 2026-09-14. Its balance cache is cash-only, so MMF rows read ~$0."
metadata: 
  node_type: memory
  type: reference
  originSessionId: e1b43ac1-efc3-4110-be2c-6e4e0ccb787d
  modified: 2026-09-14T21:13:26.265Z
---

**Kevin, 2026-09-14: "the prophet endpoint is consumed by nova."** I had told him venture's ACE money-market-ledger controller was the consumer — incomplete. Remember nova when assessing blast radius on anything touching treasury's Prophet ledger.

**The endpoint:** `CustomerAccount::Ledger`, handled at `treasury/app/handlers/customer_accounts_handler.rb:310` (`paginated_ledger_response`) → `LedgerEntries::PaginationService.fetch_page`. Supports `limit` + `cursor_after`. This is the **paginated** ledger path, distinct from the unpaginated REST `account_details` the fsfm banking UI uses.

**nova's client:** `graph/src/clients/treasury/operations/customerAccounts/batchGetLedgers.ts` — parses `balance_cents` → `balance` (`:118`, `:134`). Callers: `graph/src/lib/entity/financialAccounts.ts:257`, `graph/src/services/distribution/pipelineExport/index.ts:349`, `graph/src/services/paymentTransfer/manualReconcile/index.ts:78`. I could not trace the row `balance` to a rendered surface (nova's account balances come from a separate balances endpoint, `financialAccounts.ts:83`), so the wrong value may be parsed-but-unrendered — do not claim it is user-visible without checking.

**The defect (follow-up to BANK-2091):** `PaginationService` builds balances from `Accounts::BalanceService.revised_balances_for_account` (`accounts/balance_service.rb:101`), which applies `.not_yield` and counts position legs — i.e. the **cash** running balance, structurally ~$0 on an MMF account. Same bug [[mmf-account-ui-invested-liquidated-bug]] fixed on `account_details`; this path bypasses `money_market_fund_ledger` entirely.

**Design constraint for the fix:** `revised_balances_for_account` has ~6 callers — admin GraphQL ledger view (`query_resolvers/ledger_entries_resolver.rb:71`), CSV export (`ledger_entries/csv_resolver.rb:32`), `api/transfers_controller.rb` (`:162`, `:245`), and PaginationService (`:70`). Fixing in place changes every surface at once; scoping to PaginationService is narrower. Pick deliberately and check the transfers-controller callers aren't feeding a decision rather than a display.
