---
name: project_terran-robotics-wire-omnibus-shortfall
description: "UNRESOLVED $1,910.10 owed GHB omnibus -> SVB FBO omnibus from the Terran Robotics erroneous wires; CA 158345 ledger reads clean so no check fires"
metadata:
  node_type: memory
  type: project
---

Terran Robotics erroneous wires (**IW 297083 $125.00, IW 297383 $1,785.10**) into `CustomerAccount 158345` (FBO Investors in Terran Robotics Inc.). Slack thread #ops-banking-eng `C04HNN86DP1` parent ts `1784213764.761279`; Grace Cunnie reopened it 2026-09-16 asking Kevin to confirm reconciliation. Full trail: https://arti.internal.angellist.com/s/terran-robotics-wire-recon

**PARKED 2026-09-17 by Kevin ("let's park it, we can work on it later") — analysis complete, no repair executed. Grace is still waiting on an answer in-thread; nothing has been posted to her.**

**Status as of 2026-09-17: NOT reconciled. $1,910.10 still owed from the GHB FBO omnibus (sub-account 349505) to the SVB FBO omnibus (sub-account 137686).**

**STATUS 2026-09-30: forwarder fix SHIPPED as PR #9021 (BANK-2179, branch `kevinliang/bank-2179`). The $1,910.10 is STILL OWED — repair not built.**

- PR #9021 (2026-09-30, after Harsohail's review) = `return!` books a SAME-account return leg as `FUNDS_MIGRATION` + FUNDS_MIGRATION_FORCE_REASON, which the auto-forward already skips; cross-account (reassigned wire) stays RETURN. Force kept because without it `migration_balance` subtracts the wire's own in-flight ingestion forward; `return!` adds an explicit `available_balance` gate (raises RecordInvalid) to replace the check the force skips. Gate passed 2 clean rounds. Pre-existing finish-step bug ($0 revision raises, all categories) filed BANK-2194. Who triggered all 7 RETURN transfers: UI (Nate, Harsohail), API, console (Taylor), Temporal worker — all via `return!`.
- The `incoming_wires/state_service.rb:498` forwarder was NOT a second instance — its only caller is wire ingestion (`:131`), and the incident's force_note exists only at `transfers/v2/state_service.rb:387`. Plan C's "fix both forwarders" was wrong.
- **The maintenance task (two FUNDS_MIGRATION legs) is WRONG, parked on `kevinliang/terran-trueup-task-parked`, not a PR.** Both sub-account rows measure `ledger_balance` exactly $0.00 (every entry pulled 2026-09-29: 137686 13 entries, 349505 17 entries, both close to zero). A CA-scoped FUNDS_MIGRATION writes an LE with from/to_sub_account (`transfer.rb:632-633`), moving them to +/-$1,910.10 — attributing pool-level cash to a CA that owns none. 163,620 sub-accounts share SVB acct <redacted>. The repair needs an instrument with no CA attribution; unsolved.
- A `BalanceChecks::ResolutionService` guard was written and REVERTED: `EXCLUDED_PROGRAMS` already covers SVB/FRB/GHB Omnibus (all three of this CA's programs), and `pending_return` is the wrong window — the wire hits `Returned` within 5 min on an internal fact, before the bank executes. Real gap filed as **BANK-2182**.
- Nothing sweeps a FUNDS_MIGRATION repair back: V2 forwarder exempts it at `:355`, auto-heal excludes SVB and GHB Omnibus.

**T89803 filed as BANK-2180, out of scope:** T89803 — $460.00, 8 Apr, Grasshopper Main 463309 → Piermont 491363, from IncomingWire 214178. Same shape (a completed `FORWARD-` transfer that undid a deliberate RETURN), still outstanding, never analysed. Separate issue or in scope?

**DO NOT run the raw TP ACH repair. Five adversarial reviewers killed it 2026-09-25, and the earlier version of this file recommended it.** Why it fails: every SVB sub-account shares one physical DDA (3301234469, the BAI2 concentration account), and `app/services/bai2_sync_files/ach_processing_service.rb:323-343` turns *any* unmatched ACH credit there into a provisioned `IncomingWire` — no amount floor, no match against pending transfers. The $1,910.10 would mint orphan wires plus Flowdash tasks, and they could **not** be washed the way Taylor washed IW 314101: `GlobalLedger.confirm_balances_sum_to_fbo_balance!` is SVB-specific, so `return!` leaves cash up $1,910.10 against flat treasury → `ErrorTracker.critical`, page to #banking-alerts, and **the whole SVB previous-day BAI2 transaction rolls back, every day, until someone undoes it.**

**A recorded transfer does NOT hit that catch-all** — this is what plan C rests on, and it is demonstrated, not argued. In July, T199653/T199654 arrived at SVB and were matched and completed via BAI2 file 1399 with no wire created. The SVB ACH catch-all fires ~7 times per 90 days and every one is a genuine third-party deposit (Map3, Currency Cloud, Blue Field VC). A raw unrecorded ACH has nothing to match and falls straight into the catch-all; a recorded transfer gets matched. That is exactly why the raw design failed and this one does not.

**The sanctioned path is open:** `can_cross_transfer?(349505 → 137686, FUNDS_MIGRATION)` = **true** in prod, and `FUNDS_MIGRATION` is one of the two force reasons that legitimately clears the production SVB block in `app/services/cross_transfers/create_service.rb:59-78`. That block requires a named human `force_reason` — the raw TP call quietly bypassed the approver requirement.

**The 7/16 wash is CORRECTLY balanced — the reviewers' proposed "step 2" was a false alarm, checked before building on it.** LE 5747986 debits `EXTERNAL_INCOMING_FUNDS#32`, LE 5749375 credits `EXTERNAL_OUTGOING_FUNDS#33`, both GHB-scoped, and `check_ghb_omnibus!` subtracts *both* balances, so the pair contributes +1,910.10 then −1,910.10 = zero. No unreturn needed. Plan C is 2 steps, not 3.

**Much bigger finding, unticketed:** `check_ghb_omnibus!` raises live — "Internal $2,993,111.37, External $3,044,440.74, Difference **−$51,329.37**". This incident contributes **nothing** to it: our transfers net +$1,910.10 into GHB (T197146 + T200394 + T200395 in, T199653 + T199654 out) against +$1,910.10 of actual cash — they agree. The −$51,329.37 is entirely someone else's break. It never pages because `ghb_omnibus_activity.rb:10` is a bare `rescue` that logs and returns. Per Datadog, `ghb_omnibus_balance_mismatch` has been non-zero continuously since 7/28, drifting −$35k → −$150k.

**Artifact is STALE at v5** (2026-09-25 18:22) — it holds the rejected two-leg raw-ACH design, written 24 minutes before the reviewers killed it. Rewrite it before using it as the record.

---

**REJECTED 2026-09-25, kept only as the record of what was ruled out — do not execute:** move the cash **GHB → SVB**  — Kevin's instinct was SVB → GHB, which is backwards; SVB is the short side. Do it as a **raw TP ACH with NO ledger entry**, because `ledger_balance` is already correct at 0.00 on every sub-account (measured 2026-09-25) and only the cash is wrong. Values all resolved in prod:

**TWO legs, not one** (Kevin pushed on this and was right). Nothing forces a split — `requires_svb_ach_split?(from: 349505, to: 137686, amount: 1910.10)` = false, because the rule is `from_sub_account.svb? && !to_sub_account.svb? && amount > MAX_ACH_AMOUNT` ($1M) and this moves *into* SVB. The reason is reconciliation: every prior leg was per-wire and paired, and Grace reconciles the SVB portal by amount, so a single $1,910.10 credit matches neither of her lines.

```ruby
LEGS = [{ wire_id: 297083, amount: '125.00',  token: 'terran-omnibus-trueup-158345-12500' },
        { wire_id: 297383, amount: '1785.10', token: 'terran-omnibus-trueup-158345-178510' }]
TreasuryPrime::ApiService.post(
  treasury_prime_instance: SubAccount.find(349505).treasury_prime_instance,  # main
  endpoint: 'ach',
  body: { account_id: 'acct_11j0pmd219kc8dr', counterparty_id: 'cp_11hkp0d7104r3sv',
          amount: leg[:amount], direction: 'credit', sec_code: 'web', service: 'sameday' },
  idempotency_token: leg[:token],
)
```
Full guarded script with DRY_RUN in the artifact; dry run passed 2026-09-25. Cost of two legs: two unassigned inbound records at SVB to wash instead of one.
`GHB Omnibus.treasury_prime_manco?` is false → plain `treasury_prime_counterparty_id`, not manco. `formatted_amount` returns `"1910.10"`. Same shape/direction as T199653/T199654 which ran GHB→SVB in July. Body shape from `treasury_prime/transfers/v2/state_service.rb:117-154`.

**A `FUNDS_MIGRATION` transfer is the WRONG instrument here** (I recommended it mid-session and had to retract): `Transfers::V2::CreateService` moves the cash *and* writes an LE with from/to_sub_account, landing at cash 0/0 but `ledger_balance` −1,910.10/+1,910.10 — one skew traded for another. It is right for the canonical [[funds-migration-autoforward-stranding]] case, where the ledger *starts* skewed; here it does not. **Check `ledger_balance` per sub-account before choosing the instrument.**

**NO balance check covers this.** `BalanceCheck::Record.where(sub_account_id: 137686).count` = 0, and 349505 = 0 — zero records ever, not zero failing. Omnibus-backed sub-accounts aren't checked: TP reports $3,044,440.74 on 349505 (the whole pooled GHB FBO balance, not this CA's slice), and SVB isn't in TP at all (`GET /account/` → 404), so treasury cannot read that bank balance by any path. This class of divergence is invisible to our tooling by construction — the bigger finding than the RUV itself.

**Evidence basis:** the ±$1,910.10 is derived leg-by-leg from transfer metadata, TP ACH ids and SVB BAI2 confirmations, cross-checked against Grace's SVB portal screenshots. The omnibus balances are pooled across thousands of accounts, so no direct balance read can confirm a $1,910.10 slice — the leg trail is the strongest available evidence, not a gap to close. Kevin said "I'm moving the money back" in-thread on 2026-07-23 — **no record it happened**: last activity on CA 158345 is LE 5757532 at 2026-07-20 17:51 UTC, no transfer after T200395, and a string search of `Transfer` + `LedgerEntry` for `11n5mbmxak9b5s0` returns nothing outside T200395's own metadata.

**Why nothing alerts:** `CustomerAccount 158345` and all three of its sub-accounts return **$0.00** from `SubAccounts::BalanceService.full_internal_balance`. The 7/20 return entries (LE 5757530, 5757532) booked the outbound wire return as leaving **349505** (`from_sub_account_id: 349505`, `to_sub_account_id: 137686`) while the cash physically left **137686**. Nets to zero at the CA level either way, so per-account balance checks pass — the mismatch only exists at the omnibus level. **A CA-level transfer is the wrong repair instrument** (CA 158345 is already correct); this needs an inter-omnibus true-up.

**Systemic bug (no ticket yet):** `IncomingWires::StateService.return!` routes funds to the wire's *original* sub-account so the partner bank can return them, then the transfer-completion hook immediately auto-forwards them back to the *active* sub-account (`force_reason: FUNDS_MIGRATION`, force_note "Auto-forwarding funds from inactive sub account to active sub account upon transfer completion"). **The return is defeated by design whenever the original sub-account is inactive** — hits any wire returned out of a legacy omnibus. Here: T199653/199654 (GHB→SVB, `ach_11n5j95bajyxavc`/`ach_11n5j95cajyxb56`) were undone within a day by T200394/T200395 (SVB→GHB, `ach_11n5mbmxak9b5tz`/`ach_11n5mbmxak9b5s0`). Same family as [[funds-migration-autoforward-stranding]].

**Duplicate-wire sweep: NONE.** Only two `IncomingWire` rows mention Terran Robotics DB-wide (distinct SENDER REFs `2026072000907700`/`2026077000592300`, distinct `bank_reference`s, distinct Mercury invoices); only two wires ever on CA 158345; an all-accounts sweep 2026-03-01..09-18 for $125.00/$1,785.10/$1,910.10 returns just those two plus IW 314101; exactly six transfers ever between 137686 and 349505. **IW 314101** is the only duplicate-shaped record — the $1,910.10 DCR-reversal ACH (`txc_15wp57gxgajnh543`) ingested 7/16 while T197146 booked the same money into CA 158345 — and Taylor washed it (LE 5747986 in, LE 5749375 out, never assigned to a CA).

**Cleanest framing of the shortfall:** SVB has three debits against two credits — 3/21 forward out, 7/17 auto-forward out, 7/24 wire return out, vs. March wires in and 7/16 return-transfers in. Remove the 7/17 auto-forward and SVB nets exactly zero, so that single leg is the whole $1,910.10.

**Query trap:** filtering LedgerEntry on `origin/destination = CustomerAccount 158345` MISSES the outbound return legs — LE 5772438/5772439 (7/25, `IncomingWire -> GlobalAccount#2`) have the wire as origin, not the CA. Same for the intake legs LE 5474452/5474493 (`GlobalAccount#1 -> IncomingWire`). Query by IncomingWire id too, or you will wrongly conclude treasury never recorded the bank-side return.

Sub-accounts on this CA: **137686** = SVB FBO (rtn 121140399, acct <redacted>, `closed_at` 2023-03-10 but the real SVB account is live — Grace reads it in the SVB portal); **349505** = GHB omnibus (rtn 026015024, acct <redacted>, active); 304661 closed.
