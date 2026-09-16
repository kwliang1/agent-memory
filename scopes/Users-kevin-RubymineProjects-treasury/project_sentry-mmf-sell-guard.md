---
name: sentry-mmf-sell-guard
description: "Sentry 7590196523 (MMF sell \"Insufficient Funds\") is fixed by PR"
metadata: 
  node_type: memory
  type: project
  originSessionId: 1a9c49f3-eb98-40b6-b482-23a21c7bbf12
---

Sentry issue 7590196523 (`RuntimeError: Insufficient Funds in the Money Market Account to initiate this Liquidation`, `Api::MoneyMarketFundsController#sell`, first seen 2026-07-02) is caused by `order_service.rb` comparing sell amount against `available_balance` (cash), which is ~$0 on MMF accounts once buys post MMF_BUY position legs. Kevin hypothesized `net_liquidation_value` as the fix; verdict (2026-07-08): wrong comparator too — NLV includes cash, which Frec liquidation can't sell. Correct comparator is sellable position (position_balance − pending sells), which is exactly PR #8061 / BANK-1484 (worktree treasury-pixel, sibling session). Resolution: merge #8061; do not build a parallel fix. See [[fbo-mmf-association]].
