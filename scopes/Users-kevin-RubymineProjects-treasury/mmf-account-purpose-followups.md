---
name: mmf-account-purpose-followups
description: Deferred follow-ups after the MMF account_purpose→provider read cutover (PR
metadata: 
  node_type: memory
  type: project
  originSessionId: 8d4aa634-97ad-4f10-8068-b07fd943221c
---

PR #7929 cut over MMF-account *detection reads* from `CustomerAccount#account_purpose == MONEY_MARKET_FUND` to provider presence (`money_market_fund_account?` → `AccountProvider::MoneyMarketFund`). `account_purpose` writes are retained. Two follow-ups the user explicitly scoped OUT of #7929 (each its own task):

1. **Admin UI still displays `account_purpose`** in places (e.g. the Linked Accounts dropdown labels and IVC Balances rows label MMF accounts via account_purpose — "Money Market Fund"). Update those displays to the provider-based signal.
2. **Funding-account association should key on `owner_entity_api_id`.** The association from an MMF account to its eligible funding accounts (the IVC → VAC group) currently uses a different grouping; switch it to associate funding accounts by `owner_entity_api_id`. (Matches the MMF design: a buy's funding CA may be any member of the group.)

As of 2026-06-24 the merged stack is #7921→#7857→#7896→#7890; #7929 (the read cutover + dead-code removal of `MoneyMarketFundAccounts::InfoService#money_market_fund_account?`) is open.
