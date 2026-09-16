---
name: treasury-cron-schedules-cdk8s
description: "Where treasury's scheduled-rake schedules actually live — MOVED from cdk8s/schedule.ts to the Temporal registry; how to verify one is firing"
metadata: 
  node_type: memory
  type: reference
  originSessionId: 8f98d3d9-7cd1-4e4d-8b90-e36aca3fab2b
  modified: 2026-09-02T22:52:51.650Z
---

**As of 2026-09-02 the schedules live in `lib/temporal/schedules/registry.rb`, NOT `cdk8s/schedule.ts`.** That file still exists but both its arrays (`treasurySchedule`, `dibsSchedule`) are now **empty** — its own header comments say the recurring rakes moved to the Temporal scheduler. A grep of `cdk8s/schedule.ts` on a stale checkout will happily show you the old entry and line number; that is the trap.

Registry shape: `Temporal::Schedules::Registry::DEFINITIONS`, keyed by schedule id → `Definition.new(workflow_class:, workflow_id:, task_queue:, spec: Temporalio::Client::Schedule::Spec.new(cron_expressions: [...], time_zone_name: ...), environments: [:production])`. Default `environments` is production-only. `spec/lib/temporal/schedules/registry_spec.rb` asserts only that each definition *has* a cron expression — never the value — so changing a cadence needs no spec change.

Example (2026-09-02): `money-market-fund-reflect-yield-positions` → `Temporal::Workflows::MoneyMarketFunds::ReflectYieldPositionsWorkflow`, was `'0 0 1-10 * *'` + `time_zone_name: 'America/Los_Angeles'`; BANK-1952 moved it to `'0 * * * *'`. `time_zone_name` is a no-op for an hourly cron but the file already pairs tz with interval crons (`ledger-validate-account-totals`), so leaving it is consistent.

**Historical (pre-move, still true of old commits):** entries were `{task, on, notify}` in the `treasurySchedule` array; `@angellist/infra/cdk8s`'s `CronJob` emitted one Argo `CronWorkflow` each (`cron.ts:269,322,285`), created only when `enableCron` (true in `prod-us-west-2-zeus.yaml`, false in staging), interpreted in America/Los_Angeles. Sentry Cron monitors synced from that file.

Still true: "task X has no cron schedule" is usually wrong if the person only checked the `.rake` file — now grep the Temporal registry.

Verify a cron is actually firing (Datadog APM): spans `service:treasury-cron resource_name:*<task>*`, `operationname: rake.execute`, `env:production`, zeus cluster. Spans are `retainedby: diversity_sampling` so low-volume crons drop some traces — absence of a span ≠ missed run.

Confirmed 2026-08-26 (pre-move): the yield cron fired 8/10 days in the Aug 1–10 window. Harsohail asked if a missing cron was a gap — it was not; he'd only checked the rake file. The genuinely unscheduled sibling is `money_market_funds:download_mmf_transaction_confirmations` (`money_market_funds.rake:10`). Yield service = `MoneyMarketFundAccounts::YieldService.reflect_yield_deposits!`. Related: [[treasury-stale-shared-checkout]], [[mmf-yield-dedup-keys]], [[mmf-sell-fee-skip-regression]], [[mmf-balance-check-multiprovider]].
