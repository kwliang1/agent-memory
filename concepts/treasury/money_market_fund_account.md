<!-- machine-owned: regenerated every run, never hand-edit -->
---
concept: [treasury, money_market_fund_account]
related:
  - [treasury, money_market_fund]
  - [treasury, customer_account]
  - [treasury, transfer]
---
symbols:  MoneyMarketFundAccounts::BalanceService, MoneyMarketFundAccounts::InfoService, MoneyMarketFundAccounts::MigrationService, MoneyMarketFundAccounts::OrderService, MoneyMarketFundAccounts::Statements::FetchService, MoneyMarketFundAccounts::Statements::FetchService::Category, MoneyMarketFundAccounts::Statements::GeneratorService, MoneyMarketFundAccounts::YieldService
files:    app/services/money_market_fund_accounts/balance_service.rb, app/services/money_market_fund_accounts/info_service.rb, app/services/money_market_fund_accounts/migration_service.rb, app/services/money_market_fund_accounts/order_service.rb, app/services/money_market_fund_accounts/statements/fetch_service.rb, app/services/money_market_fund_accounts/statements/generator_service.rb, app/services/money_market_fund_accounts/yield_service.rb
indexed:  b9e45f71df9f1334507931a1f0b575bc976578a7
<!-- end machine-owned -->

## Judgment
Frec's uninvested cash sits in a sweep whose interest never arrives as a Frec yield event, so the MMF balance check drifts by that interest. Once Frec confirmed the source, Kevin's call was to book it as a YIELD leg; draft the script for Kevin to run, don't book it yourself. See [[mmf-frec-uninvested-cash-drift]].
src: -Users-kevin-RubymineProjects/8783e5da-d5b1-4a0d-b612-a64382e9e8db.jsonl 2026-09-23T17:04:14Z "confirmed we should reflect the 0.17 as yield"
