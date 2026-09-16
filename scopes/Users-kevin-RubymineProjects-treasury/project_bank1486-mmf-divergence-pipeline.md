---
name: bank1486-mmf-divergence-pipeline
description: "BANK-1486 / PR #8067 — MMF Frec position-divergence monitoring, re-architected into the 8h balance-check pipeline; pushed + CI green, awaiting review"
metadata: 
  node_type: memory
  type: project
  originSessionId: 93d1ce31-249f-49e2-b40a-68d3d847bf70
  modified: 2026-07-27T17:48:35.535Z
---

**BANK-1486 / PR #8067** (branch `kevinliang/bank-1486-v2`, commit `1d48e8209`, signed+verified). CI fully green (all Buildkite incl. 4 rspec shards, sorbet, packwerk, brakeman, datadog-validate); Cursor Bugbot + depthfirst clean. `mergeState: BLOCKED` = REVIEW_REQUIRED (human approval pending) as of 2026-07-27.

**BASIS CORRECTED (2026-07-27, after Kevin gave the real prod Frec payload):** the check is **total-to-total, zero-tolerance**: internal = `CustomerAccount#net_liquidation_value` (CA cash + position), external = Frec `account_portfolio` **`totalEquity`** (holdings + cash). Real Frec shape = `{ holdings:[{symbol:"OGVXX",quantity:Float}], balance:Float, fees:Int, totalEquity:Float }` — NOT the originally-assumed `portfolio.positions[].marketValue`. Method is `MoneyMarketFundAccounts::BalanceService.frec_total_equity` (parses totalEquity). NLV↔totalEquity (not position-only) is deliberate: it catches stray CA cash, which an MMF account should never have.

**Known pre-enable data finding:** CA 388937 holds **$45 stray `cash_balance`** (position reconciles to the cent vs Frec quantity $171,582.37; the $45 = a mis-booked order fee, same class as BANK-1550's CA 297703 orphan sell-fee). Zero-tolerance will flag it (and any siblings) on first run → remediate the stray-cash accounts (ledger fix) BEFORE enabling the alert. Enumeration snippet given to Kevin (NLV vs Frec totalEquity across provisioned MMF accts). Open: is Frec's own $3.41 cash on that acct also an anomaly? Frec sell fee = \$20 order + \$25 deposit = \$45 (`order.rb:10`); buy fee = \$28.

**Re-architecture (Kevin's call):** the original PR was a standalone `MoneyMarketFundAccounts::DivergenceService` + 15-min `DivergenceMonitorJob` that wrote its OWN `BalanceCheck::Record`s. That would have (a) crashed the existing 8h `ledger:balance_check` cron and (b) crashed the balance-checks admin GraphQL — both `CheckService`/`DifferenceService`/`RecordType` assume TP/DIBS sub-accounts and `raise` on MMF — plus flooded the table (96 writes/day/acct). Kevin directed folding MMF INTO the existing pipeline instead. Deleted the standalone service+job.

**Final shape (all in the one commit):**
- `MoneyMarketFundAccounts::BalanceService.frec_position(customer_account:)` — external side via `Frec::Client.account_portfolio`, parses OGVXX `marketValue`, RAISES on present-but-blank marketValue (not silent $0).
- `SubAccounts::BalanceService.external_balance` — new MMF branch → `frec_position`.
- `DifferenceService` — MMF internal = `position_balance` (not cash); in-progress metadata SKIPPED for MMF.
- `CheckService` — MMF sub-accounts (provisioned only, `.where.not(provider_account_id: nil)`) added to the 8h set + `check_all!`; **per-sub-account rescue** around the batch loop (strict fix — a constructor raise previously killed the whole cron).
- `RecordType` (admin GraphQL) — MMF external via frec_position, treasury via position_balance, BOTH anchored on the **recorded** `object.sub_account` (not active) so a bank-migrated acct still uses MMF math and never persists a wrong `resolution_status`.
- Two codified DD monitors (applied by CI on merge): `treasury-mmf-balance-check-divergence` (`.failed` gauge) + `treasury-mmf-balance-check-errors` (`.errored` gauge = Frec outage, so an outage isn't masked as "all clear").

**⚠️ PRE-PROD BLOCKER (flagged in PR + to Kevin):** the Frec `account_portfolio` response shape (`{portfolio:{positions:[{symbol,marketValue}]}}`, dollar-denominated) is UNVERIFIED against a real payload — all specs stub it. If the real shape differs (casing/nesting/cents), every MMF acct false-positives on the first cron run. Confirm before enabling.

**Kevin's original question — DD monitor pattern verdict:** the original #8067 shipped STATSD metrics but **no codified monitor at all** (not imperative — just absent). Now uses codified `ops/datadog/monitors/*.json` (identity markers + `team:nova-foundations`, applied by CI's `:sync_datadog`).

Related: [[datadog-docs-ci-owns-sync]], [[review-gate-five-reviewers]].
