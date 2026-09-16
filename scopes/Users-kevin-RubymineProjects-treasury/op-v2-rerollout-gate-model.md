---
name: op-v2-rerollout-gate-model
description: "OP V2 re-rollout: the 3 flipper-gate axes, and why 8 of 9 retro error categories cross all gates instead of nesting under them"
metadata: 
  node_type: memory
  type: project
  modified: 2026-09-11T17:18:39.563Z
  originSessionId: 041ce951-2dc5-4fa4-9bd3-9229eedf0f06
---

**Context (2026-09-11, Kevin + Harsohail Brar + Dan Cetlin, secondary/part-time project):** OP V2 rollout was rolled back; re-rollout planned via flipper gates. Source = Notion "🩹 Outgoing Payments Retro" (`3ae61e86666280368975e7e6534b462b`), Linear project **Outgoing Payments V2 Rollout** (`629316bf4842`). Banking ops counterparts: **Thomas** (Banking Ops Lead, he/him), **Grace Cunnie** (Sr Ops Assoc, Banking), **Viv Hong** (Ops Assoc, KYC). Artifact drafted: https://claude.ai/code/artifact/b3e2d302-bf28-4193-b45f-14bfe0a1f406

**The gates are THREE axes, not one** (treasury main @ `ee3740191`):
1. **9 plan gates** — `PLAN_TYPE_FLIPPER_FLAGS` (`app/services/outgoing_payment/info_service.rb:7-20`): `outgoing_payment_{simple,mirror,ivc_pull,ivc_cascade,intl_settlement,manco_intl,mirror_manco_intl,ivc_cascade_mirror,ivc_pull_mirror}`; checked by `enabled_for_plan_type?` (`:177-183`). Plan resolves from **fund topology** in `resolve_funding` (`:448-472`): has_mirror / is_manco / is_intl / needs_ivc_pull.
2. **1 processor gate** — `outgoing_payment_treasury_prime_submit` (`:207-216`). **DIBS is UNGATED** (routes on plan alone); **SVB has no flag** (reached by `route_through_svb` ops action post-resolution).
3. **1 entry-point gate** — `outgoing_payment_migration_batch` (`app/services/sub_accounts/migration_batch/state_service.rb:19`).

**KEY FINDING — 1 of 9 retro error categories nests under a plan gate; 8 cross all of them.** So gates = milestones/exposure control, but NOT the work breakdown; the 8 become a readiness bar before gate 1.
- **Contained (1):** mirror pulls → the 4 mirror plans. **Caveat: plan choice is AMOUNT-dependent** — `needs_mirror_pull?` false sends a mirror-owning fund to `ivc_pull`/`simple` (`:458,463,465`), so those flags already expose mirror funds.
- **Crosses all (8):** execution-failure propagation (`state_service.rb:73-75`); LP UI signal (only customer LE at `complete!` `:823-846`; pre-completion reject writes none `:864-876`); **premature submission — PARTLY fixed, unevenly: `processor_balance_sufficient?` runs only for Simple/MancoIntl/IntlSettlement, other 6 plans fall to `else → true` (`:246-270`)**; withdrawals→disbursements (`state_service.rb:21-30`); balance-check false positives (`info_service.rb:59-70`); SVB routing; Flowdash upserting (**gets WORSE the slower the ramp** — OP + AchPush + OutgoingWire each upsert own task, coexist during mixed ramp); mailers (zero OP refs in `app/mailers/`).

**Rough sizes (engineer-days):** stuck-payment Datadog monitor **0.5d (highest value/hour — gauges already emit, nothing consumes)**; write up the 3 empty retro headings 0.5d; processor-balance on all 9 plans 1-2d; withdrawal backfill 1-2d; balance-check FPs 1-3d (scope w/ Grace first); Flowdash dedup 3-5d; mailers 4-6d; **LP pre-completion signal 1-2wk = the only big rock**, decides whether ramp waits. First 4 items ≈ 4 eng-days, clears half the bar.

**Open decisions:** (1) real `errored` state vs processing+badge — rec: ship alert first, decide state off incident pressure; (2) restore provisioning LE vs UI-only signal — rec: cost UI-only first; (3) ramp order volume-first vs complexity-first — **needs payment counts per plan type, not pullable read-only**; `simple` is the `else` fall-through = highest volume; (4) hold ramp past first week of Q4 for mgmt-fee season (Thomas's call, from retro callout); (5) project closes at all-flags-on vs legacy-path deletion.

Related: [[op-errored-state-requeue]] (has the corrected `retryExecution`-exists note), [[op-ivc-cascade-mirror-wrong-direction]], [[bank-1750-bank-confirmed-flag]], [[bank-1847-balance-check-unaddressed-taxonomy]].
