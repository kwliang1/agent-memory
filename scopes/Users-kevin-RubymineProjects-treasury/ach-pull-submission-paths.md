---
name: ach-pull-submission-paths
description: The 3 live ACH pull submission chokepoints and their bank-contact ordering (matters for any submission-time guard)
metadata: 
  node_type: memory
  type: reference
  originSessionId: dfcef31a-2eb7-4e6c-9e48-7530c92b07c1
  modified: 2026-08-06T22:50:36.616Z
---

Treasury files ACH pulls via **3 live scheduled crons** (cdk8s/schedule.ts), each selecting its batch by `state: created`. A guard added to `AchPulls::StateService.submit!` alone does NOT cover all of them:

- **TP** — `treasury_prime:submit_ach_pulls` rake → `TreasuryPrime::SubmittableAchs::StateService.submit!` **POSTs to the bank (TreasuryPrime::ApiService.post) BEFORE** it calls `AchPulls::StateService.submit!`. So a guard inside `AchPulls::StateService.submit!` is too late for TP — the money-safety guard must go in the TP wrapper before the POST (next to its `can_submit?`/`svb?` early returns).
- **SVB** — `ach:upload_pending_aches` (17:30 daily) → `OutgoingAchFile.create_and_upload!` → `create_and_upload_aches!`. Historically the `select` block **discarded `submit!`'s return** and hardcoded `true`, so a `false`/blocked pull was still written to the NACHA file and uploaded. Fixed in BANK-1764 (#8454) to honor the boolean. `svb_can_submit` is effectively empty (SVB collapsed 2023) but the cron/scope are still live.
- **DIBS** — `dibs:submit_ach_pulls` rake → `AchPulls::StateService.submit!` → `DIBS::Client.submit_ach!`. Guard at the top of `submit!` covers this one.

`AchPull`'s `block` event (`[:created, :pending_microdeposit_verification] => :blocked`) is the right terminal state for a restricted pull: it drops the pull from every `*_can_submit` scope (all filter `state: created`), so no path re-selects it and crons don't re-page. `block!` needs no ledger reversal — a pull in those states has zero ledger entries (pull ledger starts at `provision!`). Rake crons run via `Rake::JobHandler.process!` which rescues `StandardError` per item and re-raises a summary → a raised guard would page every run; returning false + block avoids that. See [[ach-pull-submission-guard-bank-1764]] if that memory exists.
