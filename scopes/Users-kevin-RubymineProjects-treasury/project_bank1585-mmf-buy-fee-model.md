---
name: bank1585-mmf-buy-fee-model
description: MMF buy fee model — position leg is net_value_cents (PR
metadata: 
  node_type: memory
  type: project
  originSessionId: c16ecbd5-02ed-4ad1-b438-6ef8a0711896
---

BANK-1585 (2026-07-08): MMF buy completion overdrew the account — gross position leg + $28 fee leg vs gross wire credit → fee leg failed balance validation at $0-cash accounts → whole `with_lock` completion rolled back → cron retried forever. Fixed in PR #8154 (`kevinliang/bank-1585`): position leg = `net_value_cents` (actual shares acquired; net + fees = gross → cash exactly $0), matching the BANK-1547 backfill's fee model, plus a fee-floor guard in `buy!` (amount must exceed fees) and sigs on the fee arithmetic.

Key facts: `position_balance` sums only MMF_BUY/MMF_SELL/YIELD (fee legs excluded, `balance_service.rb`); NLV = cash + position is invariant under net-vs-gross; sells post MMF_SELL at gross (fees out of proceeds) — asymmetry is correct.

Open follow-ups: [[BANK-1587]] — prod audit of live-path gross MMF_BUY legs (BANK-1474→1585 window, drift/residual-cash completions overstate position), sub-fee/zero-fee pending-buy audit, `mmf.*.fee_drift` Datadog monitor. Completion knife edge under concurrent pending debits carried to BANK-1584 (adapter; candidate order-completion force_reason). Related: [[sentry-mmf-sell-guard]] (sell side, BANK-1484/#8061; second guard fixed by #8151/BANK-1583, built by sibling session "drift").

Process notes: spec/CLAUDE.md — host rspec fails (FrozenError/encryption); run in container via `docker compose exec app`. This worktree (treasury-patch) has DBs set up (`make setup-worktree` done 2026-07-08).
