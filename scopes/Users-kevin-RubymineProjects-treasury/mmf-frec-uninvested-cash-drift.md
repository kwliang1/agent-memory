---
name: mmf-frec-uninvested-cash-drift
description: "MMF balance-check gaps that are Frec uninvested cash: NLV has no slot for it, so every manual YIELD absorb goes stale when Frec's cash moves (CA 388937, 17c, 2026-09-17)"
metadata:
  node_type: memory
  type: project
---

`net_liquidation_value` = cash + position, and an MMF CustomerAccount's cash is **always 0** (its only
sub-account is the Apex/MMF one). Frec's `totalEquity` = OGVXX holdings + **uninvested cash**. So Frec's
uninvested cash has no representation on our side at all. `YieldService` only mirrors `yield_events`,
and `balance` is not a yield event — the only way it has ever been reconciled is a hand-booked YIELD leg
(YIELD is position-only, `not_yield` excludes it from cash, so a YIELD leg raises NLV by exactly its
amount). That absorb is a **point-in-time snapshot**: it goes stale the moment Frec's cash moves again.

**CA 388937, 2026-09-18 — the first one to drift.** Balance check clean at `2026-09-17 08:05:50Z`,
flagged at `16:05:47Z` and every run since, always the same 17c. Treasury NLV unchanged (77,298,056)
across all of them, so the move is Frec's. It is in cash, not holdings: `MMF_BUY − MMF_SELL + Frec's
17 yield events` = **77,297,715 = Frec's OGVXX quantity exactly**, and there is no yield event after
2026-09-02, so holdings cannot have moved. Frec cash went $3.41 → $3.58; we still carry the $3.41
booked on 2026-08-18 as LE 5816298 / `MoneyMarketFund::Yield` #33 (accrued_on back-dated to the
2026-08-04 event) — that leg is Kevin's deliberate reconcile from [[bank-1746-mmf-reconcile]] run
05af1c67, **not** a bug. I called it spurious first and had to retract.

Swept all 46 `AccountProvider::MoneyMarketFund.provisioned` against live Frec: **388937 is the only
account currently diverging**. Two others carry the same absorb and are tied only because their cash
has not moved: 432337 (YIELD $1.00 / LE 5818467, Frec cash still exactly $1.00) and 425894 (YIELD
$23.36 / LE 5801623 from the BANK-1746 UnbookedYield, plus $8.00 treasury cash = Frec's $31.36).

**Do not read `(buy − sell + frec_yield_sum) − holdings` as a trade error on every account** — for
311536 and 356027 it is large and exactly cancels their yield gap, because Frec's `yield_events` list
does not cover their full history. It is only a valid check where the two tie, as on 388937.

**What the uninvested cash actually is (Apex statements, pulled 2026-09-18).** Not loose cash at Frec —
an **Apex FDIC-Insured Sweep** deposit at a named Program Bank (388937: Schaumburg Bank & Trust,
Bloomingdale IL). The monthly statement carries a `Bank Interest` income line ($0.00 in both July and
August 2026, $2.50 YTD) and states the interest period *ends at the close of business on the 15th of
the month*. Frec's `documents` endpoint also accepts **`TRADE_CONFIRMATION`** (and `TAX_FORM`), not just
the `STATEMENT` in `MoneyMarketFundAccounts::Statements::FetchService::Category`; that is how to get the
`DAILY_CONFIRM` for a trade date. Statements are Apex PDFs behind a redirect — fetch with Net::HTTP in
the pod, `al console pull`, then extract text by zlib-inflating the FlateDecode streams (no poppler on
the host).

**`account_portfolio`'s `fees` field is cumulative fees in DOLLARS, not cents.** 388937 reads 1254 =
26 sells x $45 + 3 buys x $28, exact. Do not read it as a cents amount.

**17c source: CONFIRMED by Frec (Slack C04U4335VND, ts 1790029226.211749, Ashley Rodabaugh
2026-09-22).** It IS Apex sweep interest: the ~$3 sitting outside OGVXX is auto-swept into Frec's money
market account and earned $0.17 — on cash that "has been there since trading in August 2025", i.e. ~13
months of accrual, not one period. I had the right hypothesis and **wrongly refuted it** by modelling a
single 30-day accrual on $3.41 (~1c) and by a cross-account test (BUY #52/#54, SELL #160 accounts show
$0.00 cash) that only holds if accrual windows are equal — they are not. Lesson: bound the accrual
window from the balance's AGE, not from the observation window.

Frec agreed to buy OGVXX with the residual cash (reply 4). That does NOT move `totalEquity`, so booking
the yield stays correct; afterwards position == holdings with zero cash and this account's structural
gap closes. Kevin authorised reflecting the $0.17 as yield 2026-09-23 and ran it from his own write console
(mine had lapsed). Frec's UI labels the posting **"FDIC Sweep interest, $0.17, Sep 17 2026 6:31 AM,
account Cash"** — so accrual is dated `Time.utc(2026, 9, 17)`, not the 9/15 interest-period close I
first picked. 6:31 AM is PT-or-ET (unstated) but either lands on 9/17 UTC, and it falls inside our
own window: balance check clean 09-17T08:11:21Z, flagged 16:10:41Z.

**Handing a script to Kevin for HIS console:** no `exit` (it kills the session) and no constants (they
warn on re-run) — wrap in a `lambda` taking `dry_run` and short-circuit with `next`, raise
`ActiveRecord::Rollback` for the dry run, and assert the post-write NLV equals live Frec `totalEquity`
inside the transaction so a wrong result cannot commit. Script kept at
`~/.tide-scratch/fix_388937_uninvested_cash.rb` — **not** `/tmp`, which macOS purges after 3 days and
which ate the first copy.

**RESOLVED 2026-09-25 (verified on prod, write console).** Kevin ran the script 09-23 21:57Z →
`MoneyMarketFund::Yield` #53 / `LedgerEntry` 5880398, 17c, accrued_on 2026-09-17. Frec then executed the
consolidation buy **fee-free** (`fees` still 1254 = 26x$45 + 3x$28, unchanged — the $28 order fee I
flagged as the one real risk was waived). End state: Frec holdings 772,980.73 / cash 0, treasury nlv =
position = 77,298,073, **gap 0 with composition matching**, not just the total. Clean on every check
since; fleet sweep of all 46 provisioned accounts shows 0 diverging.

**Still carrying the same latent shape:** 425894 ($31.36), 432337 ($1.00), 295243 ($8.00) hold stuck
Frec cash absorbed as YIELD legs. All tie today and each reopens when its sweep interest posts — 388937
only surfaced because its residual had sat since Aug 2025. Recommended to Kevin: ask Frec to consolidate
those three to zero cash the same way, which closes the class instead of repeating this three times.

**When checking whether the balance check is "clean", prove the cron ran.** A `BalanceCheck::Record` is
written only on mismatch AND `DifferenceService#run!` swallows errors, so "no record" and "never ran"
are indistinguishable per-account. Confirm with `BalanceCheck::Record.where(checked_at: X..).group(:run_uuid)`
— runs land every 8h at ~:05.

**How to apply:** for any MMF balance-check gap, first compute `buy − sell + Frec yield_events` against
Frec `holdings`. Tie means the whole gap is uninvested cash and a hand-booked YIELD leg just restarts
the clock; propose modelling `balance` as its own quantity (or reconciling against `holdings`) instead.
Query path in [[treasury-console-pod-stdin-eof-workaround]]. Related: [[mmf-balance-check-multiprovider]],
[[treasury-three-balance-functions]].
