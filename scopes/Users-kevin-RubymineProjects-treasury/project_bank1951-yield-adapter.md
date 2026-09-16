---
name: bank1951-yield-adapter
description: "BANK-1951 PR #8772 — YieldService routes yield_events via Adapters::Base.for(...).fetch_yield_events; adapter method pre-existed (#8071), only call site changed; BANK-1953 stacks on it"
metadata: 
  node_type: memory
  type: project
  originSessionId: 0ecebd07-9f46-4482-9c3d-4c1ba9ee4a52
  modified: 2026-09-02T23:05:52.285Z
---

BANK-1951 (PR #8772, branch `kevinliang/bank-1951`, commit a12293a14, opened 2026-09-02): `MoneyMarketFundAccounts::YieldService.reflect_yield_deposits!` now calls `MoneyMarketFund::Adapters::Base.for(account).fetch_yield_events` instead of hardcoded `Frec::Client.yield_events`, and uses the `.provisioned` scope. Gate passed (R2+R3 5/5 clean); Buildkite #33658 green + Cursor Bugbot approved; awaiting human review/merge.

**Why:** the Linear ticket's steps 1–2 (add abstract + Frec impl) were already done in #8071 — only the call site was missing. Only behaviour divergence is on malformed data (`''` provider_account_id / orphaned binding, no FK): fails before the HTTP call inside the same per-account rescue.

**How to apply:** BANK-1953 (drop `frec_yield_event_id`) stacks on this branch — don't amend #8772 after 1953 is built without restacking. `Provider` enum is Frec-only with `T.absurd`; adding a provider is a compile error, not runtime. See [[bank1493-mmf-ct-rail-retire]] for the broader MMF adapter context.
