<!-- machine-owned: regenerated every run, never hand-edit -->
---
concept: [treasury, money_market_fund]
related:
  - [treasury, money_market_fund_account]
  - [treasury, application]
  - [treasury, sub_account]
---
symbols:  MoneyMarketFund, MoneyMarketFund::Adapters::Base, MoneyMarketFund::Adapters::Base::ApplicationStatus, MoneyMarketFund::Adapters::Frec, MoneyMarketFund::Buy, MoneyMarketFund::Buy::State, MoneyMarketFund::Order, MoneyMarketFund::Sell, MoneyMarketFund::Sell::State, MoneyMarketFund::Yield
files:    app/models/money_market_fund.rb, app/models/money_market_fund/buy.rb, app/models/money_market_fund/order.rb, app/models/money_market_fund/sell.rb, app/models/money_market_fund/yield.rb, app/services/money_market_fund/adapters/base.rb, app/services/money_market_fund/adapters/frec.rb
indexed:  b9e45f71df9f1334507931a1f0b575bc976578a7
<!-- end machine-owned -->

## Judgment
Page (error.critical) only when a liquidation fails and the system won't self-heal; a Temporal job that keeps retrying should not alert on each failure.
src: -Users-kevin-RubymineProjects--worktrees-treasury-flint/faf2cbfe-77db-4607-9fdb-3bcaaeb4d644.jsonl 2026-09-05T08:06:01Z "we should only alert if the liquidation fails and the system doesn't self-heal"
The async sell design assumes Frec is idempotent on retry; Kevin chose it on that assumption and confirmed it 2026-09-15. Frec dedupes on `externalRequestId`, the Sell's uuid: retry the same Sell, since a new Sell is a new order. See [[project_bank1910-async-mmf-sell]].
src: -Users-kevin-RubymineProjects--worktrees-treasury-flint/faf2cbfe-77db-4607-9fdb-3bcaaeb4d644.jsonl 2026-09-08T20:22:39Z "assume it's idempotent."
src: -Users-kevin-RubymineProjects--worktrees-treasury-flint/faf2cbfe-77db-4607-9fdb-3bcaaeb4d644.jsonl 2026-09-15T19:05:12Z "confirmed"
Register a Frec deposit account when the CCA's sub-account rotates or migrates, never at sell time: the new sub-account can lag. See [[mmf-frec-deposit-account-routing-collision]].
src: -Users-kevin-RubymineProjects/c76468f9-033e-4543-8d38-efc8942d056e.jsonl 2026-10-06T22:59:54Z "this is a no go, there may be a delay in the sub account creation"
