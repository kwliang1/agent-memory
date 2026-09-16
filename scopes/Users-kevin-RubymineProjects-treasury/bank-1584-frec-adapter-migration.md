---
name: bank-1584-frec-adapter-migration
description: "BANK-1584 executed — routed MMF OrderService order mechanics through the Frec adapter + adapter now owns funded_by_mmf_position via a predicate. PR #8462. The adapter seam confusion came from BANK-1487, not 1584."
metadata: 
  node_type: memory
  type: project
  originSessionId: 97c182d9-2bf7-42e2-939f-c9391021d6a1
  modified: 2026-08-07T19:04:41.466Z
---

BANK-1584 ("Introduce a Frec/MMF execution adapter; absorb the funded_by_mmf_position flag") — **executed 2026-08-07**, PR https://github.com/angellist/treasury/pull/8462 (branch `kevinliang/bank-1584`, worktree `.worktrees/treasury-1584`). Linear left at Backlog — flip to In Review to trigger PR sync.

**Why it looked done but wasn't:** the `MoneyMarketFund::Adapters::{Base,Frec}` seam already existed, but it came from **BANK-1487 (PR #8071)**, which only wired it for provisioning + balance-checks. The adapter's `execute_sell!`/`fetch_deposits`/`fetch_liquidation` shipped with **zero callers** (dead code). `OrderService` still called `Frec::Client` inline and hardcoded the flag. 1584 = finishing that migration.

**What shipped:**
- `MoneyMarketFundAccounts::OrderService.sell!` liquidates via `adapter.execute_sell!`; refresh/confirmation-download polling → `adapter.fetch_liquidation`/`fetch_deposits`. Deleted inline `Frec::Client` calls, private `active_deposit_account_id`, unused `MMF_ASSET_SYMBOL`.
- Adapter owns `Transfer#funded_by_mmf_position` via new `funds_sell_from_position?` predicate (Frec ⇒ true); `sell!` applies it.
- **Key design call:** did NOT invert the `Sell`←`Transfer` creation ordering (the landmine the issue flags) and did NOT move transfer orchestration into the provider layer. The predicate gives the adapter ownership of the *declaration* only — lowest-risk reading of "absorb the flag."
- Harmonized all 4 `OrderService` batch loops with a per-iteration `rescue` (one loop was a pre-existing whole-cron abort risk for legacy binding-less rows).

Behavior-preserving (adapter issues identical `Frec::Client` args), so existing sell specs — incl. the "position, no cash" regression ([[bank-1584]] chain: BANK-1484/1583) — stay green. Verified via worktree Docker container specs (`docker exec treasury-1584 bundle exec rspec ...`) since host rspec can't boot (see [[treasury-local-dev-gotchas]]).
