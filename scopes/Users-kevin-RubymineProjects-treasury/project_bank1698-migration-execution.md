---
name: bank1698-migration-execution
description: BANK-1698 MMF CrossTransfer→V2 prod migration state — 7 contract-lapse backfills + 2 dangling-ref orders
metadata: 
  node_type: memory
  type: project
  originSessionId: 63f3b02c-749a-472a-b632-20bae0656acc
  modified: 2026-07-27T20:01:33.400Z
---

Executing `Maintenance::RecreateLegacyMmfCtOrdersTask` (PR #8338) in prod to move legacy CrossTransfer-backed MMF orders onto V2 Transfers (prereq for BANK-1493 `cross_transfer_id` column drop, PR #8320). See [[bank1493-carveout-blocked]], [[maintenance-task-array-collection-gotcha]].

**Done:** 188 live-CT-backed orders migrated by the task; the guard correctly halted on records with no valid FREC processor id. **7 "contract-lapse" orders** (UI-booked in FREC's portal pre-integration, `source: USER_INITIATED` — `get_liquidation` 404s, so no REST id ever existed) were backfilled via a one-off console script (`scratchpad/backfill_7.rb`): Sells #1/#18/#19/#20/#21, Buys #13/#34 (CTs 64605/122005/122007/122008/122009/122161/180753). Per Kevin's call, they got a distinct placeholder id `contract-lapse-manual-backfill-#{order_id}` on the missing processor-id side(s) + a common `metadata.force_note`; real ids kept where present (sells' incoming wire, Buy#34's TP wire). `order.frec_liquidation_id`/`frec_deposit_id` left nil so the confirmation cron (reads those) is unaffected.

**2 remaining orders are dangling refs** — `cross_transfer_id` set but the CT row is deleted (`s.cross_transfer` → nil), so they're invisible to the task's CT-iterating collection and not migratable:
- **Sell#2** (CT#64612, canceled 2023, no ledger): benign dead pointer — safe to `update_all(cross_transfer_id: nil)`.
- **Sell#35** (CT#133725, MMF CA 356027): turned out to be an **unfinished ledger/bank reconciliation** (not cleanly resolved). Position leg settled (LE 5718730 +$183,346, −$45 fee 4567030). CT#133725 was intentionally destroyed Jan 2025 (no TP sub → CT impossible). **Bank (TP) is correct**: $183,301 sits in CA **316624**'s active GHB sub (MBA Fund III) — wired in 11/29/24, book round-trip 12/02 "assigning wire to correct destination". **But the Treasury ledger is wrong**: the $183,301 is parked in `HOLDING_ACCOUNT_FOR_INCOMING_WIRES` (GA#46) via IW#249815 (sub 391677 = CA 316624), and CA 316624 was never credited — so the ledger understates 316624 by $183,301 vs bank. Intended shape (per Kevin): a **`356027 → 316624` V2 transfer** crediting 316624. Fix = ledger correction on immutable LEs (reverse the holding-parking 4570687/4573864 + the 356027→EXTERNAL_OUTGOING 4658174; post the clean 356027→316624 transfer + LE) — net delta: 316624 +$183,301, HOLDING −$183,301, 356027 net unchanged. Real money + cross-account → own ticket, design + review before executing; sets Sell#35.transfer_id when done. GA#8=EXTERNAL_INCOMING_FUNDS, GA#9=EXTERNAL_OUTGOING_FUNDS, GA#46=HOLDING_ACCOUNT_FOR_INCOMING_WIRES.

**Final state (2026-07-27):** BANK-1493 already **merged** — it retired the rail but **kept `cross_transfer_id` for traceability** (did NOT drop the column), so the dangling refs block nothing. Sell#2's dead pointer is optional hygiene (null whenever). **Sell#35's ledger re-representation is ticketed as [[bank1707-sell35-transfer-representation]] = BANK-1707** (Nova Foundations / MMF v2, Low): replace the EXTERNAL_INCOMING/OUTGOING workaround with a clean internal `356027→316624` Transfer, net-neutral, needs external-recon sign-off — not urgent, funds correct. Task's CT-iteration is blind to dangling-ref orders (an order-iteration would at least log them). PRs: #8338 (task, merged/Done), #8356 (dead-code kill).
