---
name: mmf-design-doc-arti
description: The canonical MMF architecture design doc lives in Arti (not the treasury repo); + the ProviderPlan→Adapters seam rename.
metadata: 
  node_type: memory
  type: reference
  originSessionId: ed23ae48-36fa-4c68-a573-33a360bb1a78
  modified: 2026-07-23T20:16:23.125Z
---

The canonical **MMF architecture design doc** is the Arti artifact, slug `mmf-architecture` → https://arti.internal.angellist.com/s/mmf-architecture (latest resolves automatically; was v124 on 2026-07-22).

It is **NOT in the treasury repo**: `docs/money_market_funds/architecture.md` + the `/treasury-mmf` skill were only ever in **PR #7780, which is CLOSED** — never merged to `main`. Don't waste time grepping the repo for them. (The two MMF docs that ARE on main: `docs/money_market_funds/account-primitive-capability-config.md` and `frec-wire-reconciliation.md`.)

Seam naming: the MMF orders ACL seam shipped as **`MoneyMarketFund::Adapters`** (`Adapters::Base` + `Adapters::Frec`, factory `Adapters::Base.for(ca)`), via BANK-1487 / PRs #8071 + #8072 (merged 2026-07-22). The design doc / MMF v2 project originally called it `ProviderPlan` — same thing, renamed. As-built `Base` has `execute_sell!` but **no `execute_buy!`** (FREC buy = memo-keyed wire), and `fetch_deposits`/`fetch_liquidation` return raw `T::Hash`.

APEX Direct is the real second MMF provider (not the hypothetical `Interchange`), tracked in the sibling Linear project **Money Market Funds — APEX Direct Integration** (BANK-1669..1693). As of 2026-07-23 it's a **two-track plan, decided by the BANK-1678 sandbox gate**: **Option A = explicit orders** (M3/M4) vs **Option B = auto-sweep** (Auto-Sweep Track milestone, BANK-1686..1690). Pick sweep iff **fully-disclosed sole-control + wire-only funding + fees netted + govt $1-NAV fund + single-asset** all confirm. Plus a common **Productionization** milestone (BANK-1691 cert/testing playbook, 1692 prod standup, 1693 monitoring reusing [[ ]] BANK-1486's `monitor_job.rb`+`BalanceCheck` pattern).

Key APEX facts (from the 2026-07-23 stress-test): Apex's auto-liquidation is `eod_redemption` on `apex.ledger.v1.Sweep` (`ledger_v2_uat.yaml`) — **sweep-gated**, so declining the sweep removes it; safety hinges on **fully-disclosed** (not omnibus) so no co-tenant debit can force-redeem the shared position. Apex MMF-sweep doc is auth-walled at developer.apexclearing.com (reachable via Kevin's Chrome, not WebFetch); enroll = `enrollment.type: CASH_MONEY_MARKET_FUND_SWEEP`, decline = `money_market_fund_sweep: MONEY_MARKET_FUND_SWEEP_DECLINE`, unenroll = Deactivate Enrollment. **Go-live gate is Apex prod-credential provisioning, ETA end-Sept/early-Oct 2026 ("like JPM") — not engineering** (~2–3 wks on sandbox). See [[csv-entity-migration-tool]] neighbors for other nova/treasury entity work.

Arti write gotcha: the Arti text API strips C1 control bytes and can't accept a ~158KB body in one exact shot — a byte-exact republish needs an append-chain (per-step sha check) or the `content_base64` path; a normal hand-transmitted `add_artifact` of a big doc will drift.
