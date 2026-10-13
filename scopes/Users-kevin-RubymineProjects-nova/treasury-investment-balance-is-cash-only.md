---
name: treasury-investment-balance-is-cash-only
description: "Every balance treasury reports for an INVESTMENT CustomerAccount is cash-only — net_liquidation_value == total_balance there, because the MMF position lives on a separate MONEY_MARKET_FUND account"
metadata: 
  node_type: memory
  type: reference
  originSessionId: b4bb1d9d-05e0-455a-a8d8-b73128746889
  modified: 2026-09-17T22:08:47.938Z
---

Verified 2026-09-17 against treasury `origin/main` (BANK-2029). **Do not render a balance for a
treasury INVESTMENT account and call it "the balance".**

**The chain:**
- Nova's `batchGetBalances` -> treasury `CustomerAccountsHandler#balance`
  (`app/handlers/customer_accounts_handler.rb:105-135`) returns `total_balance_cents`,
  `available_balance_cents`, `total_balance_end_of_last_month_cents`, and — since treasury #8044
  (2026-07-01) — `position_balance_cents` + `net_liquidation_value_cents`.
- `CustomerAccount#balance` is **cash**. Treasury's own comment one line above it:
  `# Treat this method as "total_cash_balance"` (`app/models/concerns/customer_account/balance_computation.rb:19-25`).
  `available_balance` derives from it, so it is cash too.
- `net_liquidation_value = balance + position_balance` (`balance_computation.rb:39-41`), and
  `position_balance` delegates to `MoneyMarketFundAccounts::BalanceService.position_balance`,
  which **returns `Money.zero` unless `customer_account.money_market_fund_account?`**
  (`app/services/money_market_fund_accounts/balance_service.rb:8`). That predicate is
  `money_market_fund_provider.present?` (`app/models/customer_account.rb:171`), and the provider
  hangs off an account whose `account_purpose` is `MONEY_MARKET_FUND`, not `INVESTMENT`.

**Therefore: on any INVESTMENT account, `position_balance == 0`, so
`net_liquidation_value == total_balance == cash`.** Switching a caller from total to NLV buys
nothing. Nova's zod schema at `batchGetBalances.ts` drops both new fields anyway (`z.object`
strips unknown keys) — adding them does not fix the blindness.

**Where the money actually is:** an `InvestmentVehicleConfiguration` groups sibling accounts by
role (`capital_collection_account_id`, `money_market_fund_account_id`, `gsib_vault_account_id`).
The MMF position sits on the `MONEY_MARKET_FUND` sibling. Siblings **share
`owner_entity_api_id`**, so `listCustomerAccountsByEntity` *without* an `accountPurpose` filter
reaches them — that is the fix path. The IVC join itself is **not** exposed over Prophet, so with
several INVESTMENT accounts nova cannot tell which MMF sibling pairs with which.

**Observed magnitude (local `treasury-mmfnlv`, IVC 1):** INVESTMENT cash **−$2,129,240.00**,
MMF sibling position **+$2,212,627.48**, entity net ≈ **+$83,387**. A card reading the INVESTMENT
balance renders nine-figures-negative for an entity that is net positive — worse than the $0 you
would expect.

Anything counting accounts for the commit gate must still count **only** INVESTMENT — see
`gatherPortReads.ts` exactly-one rule. Related: [[nova-transfer-balance-reservation-traps]],
[[reference_treasury_batch_account_lookup]].
