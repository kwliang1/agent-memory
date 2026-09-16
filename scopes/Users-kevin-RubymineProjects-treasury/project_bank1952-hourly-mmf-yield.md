---
name: bank1952-hourly-mmf-yield
description: "BANK-1952 hourly MMF yield reflection — schedule lives in Temporal registry (not cdk8s, moved by #8685 2026-08-27); measured 46 provisioned providers; 50/50 yields NULL frec id; qubit worktree holds the branch"
metadata: 
  node_type: memory
  type: project
  originSessionId: 0fea3d9f-a332-4764-b21a-2623227971f2
  modified: 2026-09-03T00:05:57.690Z
---

**BANK-1952** (run `reflect_mmf_yield_positions` hourly), worked 2026-09-02 in worktree `treasury-jade`.

- The Linear issue + original task prompt point at `cdk8s/schedule.ts` — **stale**. #8685 (merged 2026-08-27) moved the job to a Temporal schedule: `lib/temporal/schedules/registry.rb` `'money-market-fund-reflect-yield-positions'`, workflow `reflect_yield_positions_workflow.rb` (`start_to_close_timeout: 300`, `max_attempts: 1`). cdk8s entry + rake task are gone on `origin/main`. Always `git show origin/main:<file>` before trusting a worktree base.
- Change made: `cron_expressions: ['0 * * * *']`, LA tz dropped (hourly-at-:00 is tz-independent; matches siblings).
- Measured (prod `-w` console): `AccountProvider::MoneyMarketFund.where.not(provider_account_id: nil).count` = **46** (49 total); `MoneyMarketFund::Yield` **50/50 rows have `frec_yield_event_id` NULL** — dedup in practice is the `(customer_account_id, accrued_on, amount_cents)` unique index, as Kevin said.
- Frec baseline (Datadog APM 30d): ~12k calls ≈ 400/day, 0×429; hourly adds ~1,100/day.
- Alerting for Temporal schedule failures: Sentry via `TemporalUtils::Interceptors::ErrorLogger` (final attempt); `treasury.temporal.schedules.last_run_status` gauge exists but **no Datadog monitor** on it.
- Branch `kevinliang/bank-1952` was created by a dead session and is checked out in `.worktrees/treasury-qubit` (clean, at origin/main).
- **STATUS 2026-09-03 00:05 UTC:** signed commit `a5c2aa4ec` on local branch `kevinliang/bank-1952-jade` (worktree jade, base 452abc7a2). NOT pushed — session reaped before Kevin answered; 11 review rounds, code 55/55 clean, description converged. Ship: `git push origin a5c2aa4ec:refs/heads/kevinliang/bank-1952`, PR body saved at `memory/bank1952_pr_body.md`. Related: #8772 merged (BANK-1951); BANK-1954 (#8773/#8774) in review, touches yield_service.rb.

**Why:** two review rounds were spent on a phantom cdk8s diff before a reviewer caught the stale base.
**How to apply:** for schedule/cron tickets in treasury, check `lib/temporal/schedules/registry.rb` first ([[reference_temporal-schedules-not-cdk8s]]); verify the target line exists on `origin/main` before building.
