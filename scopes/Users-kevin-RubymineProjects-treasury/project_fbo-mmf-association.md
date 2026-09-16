---
name: fbo-mmf-association
description: "FBO accounts (capital_collection, investment_vehicle) relate to MMF accounts via owner_entity_api_id, not just IVC"
metadata: 
  node_type: memory
  type: project
  originSessionId: 215788ce-471e-49a7-80fb-6f434420db54
---

FBO (customer) accounts like capital_collection and investment_vehicle relate to money market fund (MMF) customer accounts via `owner_entity_api_id`.

**Why:** The IVC model has a `money_market_fund_account_id` column that directly links an MMF account, but this isn't always populated. The canonical fallback for discovering the relationship is through shared `owner_entity_api_id`. When surfacing MMF position/NLV in admin tooling or IVC views, the association path matters — relying solely on the IVC column may miss accounts.

**How to apply:** When building features that need to find an MMF account for a given fund/entity, check both the IVC's `money_market_fund_account_id` and the `owner_entity_api_id` relationship. This is especially relevant for [[balance-check-resolution-followup]] and any admin display that spans account types within a fund.
