---
name: project_bank1493-ct-orders-spec-cifix
description: "PR #8369 — CI fix for recreate_legacy_mmf_ct_orders spec after #8320; FINAL = spec-only REPAIR, task kept runnable"
metadata: 
  node_type: memory
  type: project
  originSessionId: 2607cbf6-5a91-4346-a1cd-6326bb7a8781
  modified: 2026-07-27T22:07:29.117Z
---

**PR #8369** (`kevinliang/bank-1493-fix-recreate-ct-orders-spec`, off main): fixes the 18 CI failures in `recreate_legacy_mmf_ct_orders_task_spec.rb` after #8320/[[project_bank1493-mmf-ct-rail-retire]] merged.

**FINAL resolution: spec-only REPAIR, task kept runnable.** Decision churned — I recommended repair, Kevin said "delete" so I deleted task+spec, then Kevin clarified he'd only meant the CT test *cases* not the whole thing → "Restore it, and make it runnable." Ended on repair. **Key fact that drove the churn:** this spec has NO non-CT cases — the task's sole job is migrating CrossTransfer-backed MMF orders to V2, so every `it`/`context` is a CT case; "delete just the CT cases" would empty the file. Lesson: when a "delete the X cases" ask lands on a file that's 100% X, surface that up front and confirm scope before deleting.

**The fix (spec-only, task untouched):** `create_legacy_order(factory, *traits, **attrs)` helper = `build(factory, *traits, **attrs, transfer: nil).tap { save!(validate: false) }`. `transfer: nil` forced LAST so `**attrs` can't override (reviewer footgun catch). Routes every legacy-order fixture through it; the one V2-backed order stays on plain `create(transfer: v2_transfer)` (dropped the deleted `:with_transfer` trait). 18/0 in container, srb clean, signed, 2 clean review rounds (the repaired spec is byte-identical to the reviewed version).

**Root cause (for the record):** #8320 did NOT remove code the task depended on — `belongs_to :cross_transfer` + `cross_transfer_id` column + `has_one :mmf_buy/:mmf_sell` all RETAINED ("for traceability"). Break was collateral: #8320 flipped shared MMF factories `association :cross_transfer` → `association :transfer`, deleted `:with_transfer`, made `MoneyMarketFund::Order#validate_transfer_existence` run `on: :create`. So legacy orders came out transfer-backed, fell out of the task's `.where(transfer_id: nil)` scope, and (under `use_parent_strategy = false`, spec_helper.rb:39) leaked stray Transfer rows breaking `Transfer.count == 0`.

**Still NOT done (separate schema PR):** dropping the `cross_transfer_id` column + `belongs_to`/`has_one` — gated on `where.not(cross_transfer_id: nil)` reaching 0 in prod (Sell#35 bespoke [[project_bank1707-sell35-transfer-representation]]; Sell#2 benign; [[project_bank1698-migration-execution]]).

**Env note:** shared `treasury-mysql-1` OOM-died mid-session (exit137); I slipped once with raw `docker compose up -d app` (spawned stray `treasury-dusk-mysql-1` placeholders, no damage to main/siblings). Use make targets / `docker compose run --rm --no-deps app` for srb — never raw compose ([[feedback_worktree-never-raw-docker-compose]]).
