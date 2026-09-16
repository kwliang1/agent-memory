---
name: repair-319597-yield-drift
description: "RepairMmfYieldCashWithdrawal319597Task guard failed 2026-09-02 because a manual yield reflection added $4,602.05 to CA 311536; repair still exact vs fresh Frec ($4,602.30); recommend live Frec read in guard, not re-pin"
metadata: 
  node_type: memory
  type: project
  originSessionId: 9f0b2d39-addc-4e90-9b0f-dc235ecf89a3
  modified: 2026-09-03T00:13:03.734Z
---

2026-09-02: `Maintenance::RepairMmfYieldCashWithdrawal319597Task` guard raised `position $4,603.73 - $1.43 != $0.25`. Cause: Kevin ran `reflect_yield_deposits!` manually from the write console at 21:48Z (16 yields), writing YIELD LE 5842448 / Yield #37 $4,602.05 (Aug accrual on the ~$2.05M liquidated by Sell #160 on 08-21). Fresh Frec `account_portfolio`: 4602.3 OGVXX, balance 0, totalEquity $4,602.30 → position − 143c == Frec exactly, so the $1.43 repair is still correct; only `EXPECTED_RESIDUAL_CENTS` (25) is stale. Wire 319597 / LEs 5824999, 5838293 untouched.

**Why:** pinned-constant residuals go stale whenever yield reflection fires (manual or scheduled; BANK-1952 makes it hourly).

**Status:** PR #8775 (branch kevinliang/repair-319597-live-frec-guard, 348359f1a) implements the live-Frec guard: read once before the mmf_sell lock, cash==0 checked before the equation, delta in the raise; 6 review rounds, last 2 clean; Buildkite #33662 green, Cursor approved (2026-09-03). Awaiting Kevin merge; task not yet run in prod.

**How to apply:** prefer asserting `position - AMOUNT == Adapters::Base.for(mmf).external_total_equity` live inside the advisory lock over re-pinning. Also: $4,602.30 residual OGVXX remains at Frec on a liquidated account — a Frec auto-sweep would recreate the 319597 corruption; book a proper Sell first. Prod read console is RBAC-blocked; `al console exec -a treasury -p -w -- bin/rails runner "$(cat script.rb)"` works for read-only queries. See [[bank1952-hourly-mmf-yield]], [[al-console-treasury-rbac]].
