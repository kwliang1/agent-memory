---
name: mmf-sell-category-cptr-impact
description: "MMF sell cash leg flipped MMF_SELL→TRANSFER (intended, BANK-1474/1476/1477); comptroller unaffected — values MMF by balance, only category dep is YIELD, zero MMF_SELL refs."
metadata: 
  node_type: memory
  type: reference
  originSessionId: 67a62c06-97c1-4f03-9eaf-5c723549d9dd
  modified: 2026-08-21T01:04:03.346Z
---

Kevin asked (2026-08-20): on CCA c2ac16205e (=CA 124653 "FBO Investors in Tenacity VC Affiliate Fund", type **Capital Collection**), MMF sells stopped showing category `MMF_SELL` — problem for cptr accounting? **Answer: no.**

**Ledger topology of an MMF sell now (post BANK-1474/1476/1477 position-leg migration):**
- Position leg on the **MMF account** (CA 358061, type "Money Market Fund"): `MMF_SELL` credit from GlobalAccount 104 (external MMF holdings) + `MMF_SELL_FEES` debit. Set in `MoneyMarketFund::Sell#complete_sell_with_position_legs!` (`category: LedgerEntry::MMF_SELL`). Still produced every sell.
- Cash leg: plain V2 Transfer `category: LedgerEntry::TRANSFER`, description "Money Market Fund Sell" (`order_service.rb#sell!` ~L82), sweeping proceeds MMF acct → CCA.
- YIELD (monthly interest) = separate entry from GlobalAccount 38, unchanged.

Verified: sell #89/#87 (2025) cash-leg cat=MMF_SELL; sell #147/#158 (2026) cash-leg cat=TRANSFER. So MMF_SELL didn't vanish — it relocated from the cash sweep to the share-redemption position leg on the MMF account.

**Why comptroller (cptr) is unaffected:**
- Values MMF asset off the MMF account **balance** via `CPTR::TreasuryClient::CustomerAccount.historical_balance(account_uuid: money_market_fund_account_id)` (`cptr/assets/external_investable_cashes/sync_service.rb`) — balance-based, category-agnostic.
- Only MMF category dependency is `:YIELD` (interest booking, `sync_interest_yields!`) — untouched.
- **Zero** `MMF_SELL` references anywhere in comptroller backend/app/lib (checked current origin/master). MMFs held at $1 NAV → no principal gain/loss to reconcile from sells; income = yield only.

Only downside is cosmetic: CCA ledger / standalone-banking view shows "TRANSFER" not "MMF SELL" (desc still "Money Market Fund Sell"). Anything filtering a CCA's inflows by category==MMF_SELL would miss them; cptr isn't such a consumer. StandaloneBanking API just passes `ledger_entry.category` through (`standalone_banking/ledger_entry_service.rb`). Related: [[bank-1584-frec-adapter-migration]].

**Flip boundary + "should we revert?" (Kevin asked 2026-08-20):** cash-leg category flipped MMF_SELL→TRANSFER at **BANK-1477 / #8011 (effective 2026-07-01)**. Empirical: sell cash legs are MMF_SELL through 2026-06-30, TRANSFER from 2026-07-01 (across 16 funds, 154 sells). **Do NOT revert — current is more correct.** Old model tagged BOTH the redemption leg AND the sweep MMF_SELL → double-count (282 MMF_SELL LEs for 154 sells, ~2×). TRANSFER on the sweep is right (internal MMF-acct→CCA move ≠ a sale). `position_balance` is counterparty-scoped to holdings_global so the sweep leg is never counted regardless of label — reverting wouldn't corrupt balances but would re-introduce the double-tag.
**Backfill lift (if ever wanted):** tiny — ~14 LEs (post-2026-07-01 TRANSFER sweeps), 15 sells, ~$2.27M. `category` is NOT in `LedgerEntry::READONLY_ATTRS` (only origin/dest/amount/id/uuid/requester/forced_by frozen) → plain `update!(category:)`, financially inert. Find via `MoneyMarketFund::Sell → transfer_metadata → ledger_entry`. <1 day script. Forward code = 1 line in `order_service.rb#sell!` metadata (+buy! for symmetry).

**CORRECTION / deeper (Kevin pushed: sweep IS an MMF sell, presentation concern, don't want description-parsing):**
- TRANSFER-on-cash-leg is a **deliberate documented design**, not a regression. `repair_mmf_sell35_cash_leg_transfer_task.rb:10` verbatim: "A native V2 sell books this as ONE internal Transfer(MMF→CCA) with a single TRANSFER ledger entry"; that task exists to RETIRE the old MMF_SELL-outgoing shape.
- Category is a **consumer contract**: treasury fires `LedgerEntries::CreatedEvent` carrying `category` to Venture/Comptroller (per same task's side-effect-suppression comment). So it's not just an admin label — comptroller receives it event-driven (the stale pull-based sync_service is only part of the picture).
- Robust non-description signal ALREADY exists: `LedgerEntry has_one :transfer through :transfer_metadata`, and `Transfer has_one :mmf_sell` — so CCA cash-leg LE → `transfer.mmf_sell` is a hard FK link. Stronger than category OR description.
- Recommended options (best first): **(1)** treasury-side surface: badge off `ledger_entry.transfer.mmf_sell.present?` — zero data/contract change; **(2)** if consumer needs it in `category` via event/proto: add a NEW dedicated category `MMF_SELL_PROCEEDS` (+ symmetric `MMF_BUY_FUNDING`; buy cash leg is also TRANSFER) — keeps MMF_SELL = redemption crisp; proto enum + gem bump + regen + cross-repo consumer audit + ~14-row backfill; **(3)** reuse MMF_SELL on sweep = lowest lift (1 line + backfill, position_balance safe since counterparty-scoped to holdings GA#104) but re-overloads MMF_SELL & reverses native-V2 decision — AVOID.
- Only unscoped MMF_SELL summer is `BalanceService#position_balance`, counterparty-scoped to `holdings_global` (GA#104) → sweep leg never counted regardless of label. Existing repair/reconcile tasks show precedent for MMF_SELL on proceeds legs. Enum already has spare `SWEEP=25`.

**RESOLVED 2026-08-20:** concern was in **venture, StandaloneBanking side** (treasury.internal admin view is venture-rendered). **Kevin decided to LEAVE AS-IS (TRANSFER).** Rationale accepted: reverting reverses the native-V2 design + re-overloads MMF_SELL for only a cosmetic gain. Noted for future: `StandaloneBanking::LedgerEntry` proto carries `corresponding_account_{type,uuid,name}` — the sweep credit's counterparty on the CCA is the MMF customer account (type "Money Market Fund"), so venture already has a non-description structural signal without any treasury change. Surfacing the `transfer.mmf_sell` FK on that proto would be the only thing needing a treasury change.
