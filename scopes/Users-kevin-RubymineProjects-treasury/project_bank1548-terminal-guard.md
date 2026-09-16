---
name: project_bank1548-terminal-guard
description: "BANK-1548 PR #8365 terminal-state guard on MMF Sell#complete_sell_with_position_legs!; defense-in-depth not live-fix; dead-code follow-up pending"
metadata: 
  node_type: memory
  type: project
  originSessionId: b83f379a-a152-4dfc-9a47-ad2e20055d2d
  modified: 2026-07-28T18:04:59.333Z
---

**BANK-1548** — added `return if current_state.terminal?` to `MoneyMarketFund::Sell#complete_sell_with_position_legs!` (`sell.rb`, in the `with_lock` block after the `ledger_entry_id` guard), mirroring `buy.rb:105`. + spec (canceled sell returns nil, posts no LedgerEntry, stays canceled). PR **#8365**, branch `kevinliang/bank-1548` off `main`, signed, 21/21 specs green, Sorbet clean, ready for review.

**Key verify-before-build finding:** the guard is **defense-in-depth / buy-parity hygiene, NOT a fix for a currently-live crash.** Both callers already cannot pass a terminal sell:
- `refresh_money_market_fund_sell_orders!` (`order_service.rb:228`) filters to `[Initiated, OrderCompleted]` + gates on `initiated?`.
- `IncomingWireSyncService.save_new_incoming_wire!` (`incoming_wire_sync_service.rb:35-46`) matches only transfers in `state: Queued`; the **sole** sell-cancel path (`order_service.rb:149-153`) cancels the sell's transfer alongside the sell (`Transfers::V2::StateService.cancel!` → transfer `Cancelled`), so a terminal sell's transfer is never `Queued`.
- The `backfill_mmf_position_legs_task` cited in the issue no longer calls this method (has its own inline logic w/ `return if sell.canceled?`).

**UPDATE (2026-07-28): recommended CLOSING the PR.** Reviewer @harsohailB asked "when would we complete a canceled order?" — legit, because the scenario is unreachable. Kevin pushed: parity-only, no functional benefit, would confuse devs? All true. Verified: sell's only cancel path is at creation (`order_service:149`, pre-`frec_liquidation_id`), separate from the complete flow → terminal sell can't reach the method. Moreover buy's guard (`buy.rb:105`) is ITSELF belt-and-suspenders (caller does `next if canceled?` at `:179` + `next` after cancel at `:191`), so "parity" matches an already-defensive guard. My rec: close BANK-1548 as YAGNI (add the guard when a caller can actually pass a terminal sell); alt = keep but rewrite as explicitly-documented invariant comment. Awaiting Kevin's decision (close PR + won't-do Linear, or keep-with-comment). CI is green + rebased regardless.

A review agent flagged `incoming_wire_sync_service.rb:69` (`transition_to!(WireCompleted)` after the guarded line 68 would raise `Canceled → WireCompleted`) — but the `state: Queued` filter makes it unreachable, so **caller-B widening was NOT relevant** (Kevin agreed).

**Dead-code follow-up (Kevin wants a SEPARATE PR):** candidates aren't cleanly dead — `refresh_*_orders!` is live via rake `money_market_funds:refresh_pending_orders` (`lib/tasks/money_market_funds.rake:6-7`); CT remnants (`belongs_to :cross_transfer` + `cross_transfer_id` on sell.rb:40/buy.rb:40) are **drain-only per [[project_bank1493-mmf-ct-rail-retire]]**, not safe to drop yet; `backfill_mmf_position_legs_task` is the best genuine-dead candidate (maintenance task, likely fully run — see [[project_bank1698-migration-execution]]). Awaiting Kevin's steer on which + now-vs-follow-up.

**CI red on #8365 was NOT from this PR — pre-existing `main` breakage, bisected.** The red is entirely `spec/tasks/maintenance/recreate_legacy_mmf_ct_orders_task_spec.rb` (`Maintenance::RecreateLegacyMmfCtOrdersTask`, BANK-1698 #8338), e.g. `expect(transfer.state).to eq('errored') → got "created"` (~17 examples). **First red main commit = `59b4d22a0` #8320 (BANK-1493 CT-rail retire)**; prior commit `58a9ab763` #8360 was green; every commit since (incl. `b0a6cc516` #8348) is red. #8320's CT/Transfer-state changes broke #8338's spec (merge skew). The CT spec lands in a *different rspec shard each build* (shard 0 on base 59b4d22a0, shard 2 on my PR) but fails wherever sharded — so checking a single shard's status misleads; check OVERALL `.state`. Reproduces locally on my branch (deterministic, not flaky). My diff never touches that file + the task has zero refs to my changed method → BANK-1548 clean; rebasing won't help (all main since #8320 is red). Fix belongs in CT-recreation task/spec. NOTE: #8356 already deleted some dead MMF balance/backfill services (relevant to dead-code thread). Tip: Buildkite logs are virtualized — fetch failures via browser DOM-scroll on the job page (raw log.txt 404s, `/log` endpoint truncates ~53KB).

Related: [[project_bank1585-mmf-buy-fee-model]] (buy-side parity), [[project_bank1486-mmf-divergence-pipeline]], [[project_bank1698-migration-execution]] (the red CT-recreation spec).
