---
name: mmf-account-ui-invested-liquidated-bug
description: "BANK-2091 SHIPPED to review: venture #35445 (Invested/Liquidated tiles) + treasury #8865 (Balance column = NLV + overview). MMF trades write 2 legs; summing both cancels. Local Cocoa repro recipe + dotenv/seed gotchas inside."
metadata: 
  node_type: memory
  type: project
  originSessionId: e1b43ac1-efc3-4110-be2c-6e4e0ccb787d
  modified: 2026-09-14T20:58:29.239Z
---

2026-09-14. Cocoa VC Fund II-A MMF page showed **Invested −$1,375,000**. Filed **BANK-2091** (Nova Foundations, assigned Kevin), now **In Review** with two PRs — independent, no landing order:
- venture **#35445** `kevinliang/bank-2091` — Invested/Liquidated tiles
- treasury **#8865** `kevinliang/bank-2091-mmf-running-nlv` — Balance column + overview

**Account:** `Banking::Fund` 1669 → treasury `CustomerAccount` **393632** (uuid `5c3c0525949c46d6918acdae8d2b2683`), Frec MMF program, CCA `CustomerAccount#318679`, holdings `GlobalAccount#104`.

**Root cause.** Every MMF trade writes TWO legs on the MMF CA: cash leg (CCA↔MMF) and position leg (MMF↔`EXTERNAL_MMF_HOLDINGS`). `TransactionsSummaryService#total_mmf_buy_amount` summed the *signed* amount of every `MMF_BUY` row, so both legs cancelled. Pre-2026-07-01 both legs carried MMF_BUY/MMF_SELL → tile read ~$0; after the native-V2 flip the cash leg is `TRANSFER` → tile renders the negation of recent buys. True: invested $8,236,216, liquidated $6,107,723, yield $84,134.48, NLV $2,212,627.48.

**Three surfaces fixed, one shared `position_leg?` predicate:** tiles (venture), Balance column (`balance_after_cents` was the *cash* running balance, structurally $0 on an MMF acct), and the **overview tab** — `combined_ledger` debited the full purchase and skipped YIELD while its header summed NLV, so Cocoa's overview header read $2,213,361.79 vs a last row of $734.31.

**Predicate that works (verified 18/18 in prod):** category ∈ {MMF_BUY, MMF_SELL} **AND counterparty is the global account NAMED `EXTERNAL_MMF_HOLDINGS`**. Type-only (`GLOBAL_ACCOUNT`) reconciles on just 15/18 — 20 legs across 3 accounts face the incoming/outgoing-funds globals. Venture keeps a type check too because `corresponding_account_name` is externally supplied for wire/ACH counterparties (originator/beneficiary/account_holder name); treasury's `is_a?(GlobalAccount)` is additionally a NoMethodError guard since `CustomerAccount` has no `name`.

**Carried forward, not fixed:** `position_leg?` matches holdings by name, `MoneyMarketFundAccounts::BalanceService` by per-program identity — can't disagree until a 2nd MMF program (Interchange) lands, then header/row invariant breaks. Also: an MMF acct with no resolvable holdings global reports NLV silently excluding its yield (`position_balance` returns 0 + logs). And venture's `AccountService#available_balance` returns NLV for MMF, so the "available" tile can exceed what's wireable.

## Local 1:1 Cocoa repro (working recipe)

1. Export prod ledger: treasury console runner dumps all 76 entries on CA 393632 → JSON (at/category/debit/amount/counterparty/description).
2. `treasury/script/seed_mmf_ledger.rb` (uncommitted) replays it. Needs `force_reason: USER_OVERRIDE` (backfilled position legs are dated BEFORE their cash legs, so the balance validator rejects insertion order) and `TreasuryEvent.skip_callback(:commit, :after, :queue_nats_publish_job)` — `Temporalio::ActivityIDReusePolicy` is undefined in the dev container and breaks ANY local seeding that creates a CustomerAccount.
3. `venture/script/seed_mmf_demo_fund.rb` (uncommitted) points a `Banking::Fund` at the seeded uuids (collection `a1b2c3d4e5f64a7b8c9d0e1f2a3b4c5d`, mmf `f5e4d3c2b1a04f6e8d7c6b5a49382716`).
4. **Must also run treasury's `Seeds::Examples::StandaloneBankingGroup`** — venture's banking seed creates `seed-fund-i` pointing at the 3 Standish demo uuids, and `FirmQuery` computes `available_balance` for every vehicle in the firm, so one unseeded sibling 404s the whole page. `account_details` short-circuits demo uuids to mock data but `pending_buys` does a real `find_by_uuid!`.
5. URL: `https://treasury.angellist.dev/<firmSlug>/funds/<fundSlug>/accounts/mmf` (banking app = `treasury.angellist.dev`, nginx→3004; NOT `/banking/...`).

**GOTCHA — venture dotenv beats the process env.** `config/application.rb:37` does `Dotenv.overload('.env.development')`, so `TREASURY_API_BASE_URI=… overmind start` silently does nothing. Override must go in **`.env.local`** (overloaded last). Treasury worktree serves **https** on its `.worktree-port` (7021+); plain HTTP returns "400 The plain HTTP request was sent to HTTPS port".

**Debugging lesson:** treasury logs status as a colour-coded field, so `grep 404` on `docker logs` finds nothing even when 404s exist. Read the *monolith* log for the failing GraphQL operation name instead — it names the query and the offending uuid.

Related: [[mmf-sell-category-cptr-impact]] (the 2026-07-01 cash-leg flip), [[treasury-local-dev-gotchas]], [[mmf-interchange-integration]].
