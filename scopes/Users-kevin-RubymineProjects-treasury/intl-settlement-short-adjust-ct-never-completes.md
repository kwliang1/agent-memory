---
name: intl-settlement-short-adjust-ct-never-completes
description: "Cross transfers to GlobalAccount#14 (intl outgoing wire settlement) never auto-complete — two independent dead ends; ~20 have been hand-completed since 2023"
metadata:
  node_type: memory
  type: project
---

**2026-09-21, diagnosing OW 135597 (stuck in `waiting_for_settlement_account_replenishment`).**

An international `OutgoingWire` that gets short-adjusted spawns a small CrossTransfer
`OutgoingWire → GlobalAccount#14` (`INTERNATIONAL_OUTGOING_WIRE_SETTLEMENT`), description
`Adjusting short amount for wire`, on the ACH rail. The wire only leaves
`waiting_for_settlement_account_replenishment` when that CT completes
(`treasury_prime/transfers/state_service.rb:150`). **That CT never completes on its own.**

Two independent dead ends, both still live on `origin/main` as of 2ce2b57608:

1. `treasury_prime/cross_transfers/state_service.rb:87-97`. TP returns the sent ACH with
   `scheduled_settlement: null` — key **present**, value nil. Line 94 tests key presence
   (`response.keys.include?(:scheduled_settlement)`), so `complete_without_scheduled_settlement:
   false`, and `can_complete_into_tp?` then demands `treasury_prime_scheduled_settlement.present?`
   — which line 91 already declined to set. Unreachable. Webhook replays re-enter the same branch.
2. The incoming-credit rescue can't save it either. GlobalAccount#14's sub-account is
   `acct_11hkntap104mscr`, which is on `webhook_service.rb` `ACCOUNT_IDS_TO_SKIP` — its
   `account.update` webhooks are stored `skipped` (last one logged at all: May 2024). And even if
   the sync ran, `ach_sync_service.rb:104` matches only `state: 'sent_pending_arrival'`, a state
   this CT is explicitly barred from: `should_mark_as_sent_pending_arrival?` excludes
   `destination == international_account`. (The Transfer-v2 lookup at :140 accepts `processing`
   too; the v1 CrossTransfer lookups at :88 and :104 were never widened.)

**Evidence it's chronic, not a regression.** Every one of the ~20 historical short-adjust CTs to
GlobalAccount#14 completed days late in batches at timestamps with *zero* webhook traffic — e.g.
207238/207244/207245/207246/207251 all at 2026-07-14 19:36:2x, created Jul 7-10. Each had exactly
three `ach.update` webhooks at creation time, all `completed`, none of which moved the CT.
Someone has been hand-completing these all along.

**Manual completion** (safe; nets to zero on both the OW and GA#14):
```ruby
TreasuryPrime::Transfers::StateService.attempt_to_complete!(
  CrossTransfer.find(<id>), complete_without_scheduled_settlement: true
)
```
`complete!` then creates the OW→GA#14 LE, and because origin is an OutgoingWire in
`waiting_for_settlement_account_replenishment` it calls `complete_offline_wire!` with
`override_amount: ct.amount + ow.amount`, which drains GA#14 to `external_outgoing_funds`.

`CrossTransfer.stalled` / `health-stalled-cross-transfers` does fire on these, but only alerts.

Related: [[treasury-prod-console-access]] — the TP API needs the **write** console; the read
console dies with `Failed to open TCP connection to :80`.

---

**Fix shipped to review, 2026-09-29 (BANK-2149).** PR **#9017**, branch `kevinliang/bank-2149`,
commit `7e52c9dc8`, signature verified. CI 33/33 green; Cursor approved with no findings.
Kevin said push after 6 gate rounds (3-6 all had findings, counter never reached 2) — **the gate was
bypassed by his explicit call**, noted here so the next reader does not assume 2 clean rounds.

Shape that survived: at `cross_transfers/state_service.rb`, keep the existing key-presence condition
and OR in a new one — `TreasuryPrime::CrossTransfers::InfoService.replenishing_international_wire_settlement?`,
shared with `complete!` so the two cannot drift. Kevin moved it to the **InfoService** (per
`.claude/rules/services.md`: predicates belong there, and AGENTS.md says do NOT copy the neighbouring
StateService predicates as precedent), and had
`GlobalAccount.international_outgoing_wire_settlement` default its `partner_bank_program:` — the arg
carried no information since `global_account.rb:118` raises unless it is GHB main. That killed the
private lookup helper entirely. It requires origin is an
`OutgoingWire` **and** that wire is `waiting_for_settlement_account_replenishment` **and** the
destination is the settlement account. Plus `complete_offline_wire!` takes an `outgoing_wire.with_lock`.

Three versions were rejected along the way — blanket `true`, `direction != 'debit'`, and pushing the
gate into `attempt_to_complete!` (see [[feedback_gate_placement_carries_preconditions]]). Don't
re-derive them.

**Prod population is ZERO as of 2026-09-29** — no wires in `waiting_for_settlement_account_replenishment`,
no open CrossTransfers to GlobalAccount#14. So no backfill is needed and the fix is purely
forward-looking; the first time it does anything is the next short-adjusted international wire.

Known accepted limitations, to state in the PR: the trigger is the `sent` webhook (no sweep re-polls
these — the ACH sweep calls `attempt_to_complete!` directly and the wire sweep filters
`treasury_prime_wire_id NOT NULL`), a miss falls back to the existing `CrossTransfer.stalled` alert;
and the row lock is not test-pinned.

**OutgoingPayment does NOT share this settlement account (verified 2026-09-29).** `OutgoingPayment::Plans::IntlSettlement`
resolves `CustomerAccounts::SystemAccounts::InfoService.settlement_account` → a **CustomerAccount** with
`account_purpose: SETTLEMENT`, display name `"Settlement Account (<program>)"`. Prod has **zero** of those
rows; the resolver is `find_by` → `create!`, so OP's settlement account is minted on first use and has never
provisioned. The wire path's is GlobalAccount#14 / sub 166754 / TP `acct_11hkntap104mscr` / GHB ***3683.
OP also has no parked state — it models the leg as a `FundingPlan` step (`Purpose::SettlementLeg`), so the
predicate cannot be shared even with a rename. **If OP's settlement account is ever meant to be the same
bank account, it must be linked deliberately** — `create!` will otherwise mint a second ledger
representation of one bank account, which is the classic balance-check drift shape.

**Verified 2026-10-01 (read-only prod):** every one of the 22 short-adjust CTs to GA#14 also completed its wire
offline — each has the GA#14→EOF drain LE (requester = the OW) for exactly `ct.amount + ow.amount`, written in the
same second as the CT completion, so all went through `complete!` rather than a forced state. OW 135597 / CT 207274:
completed 2026-09-21 22:09:26 UTC, drain LE 5875422 $1,433.31, Prophet trail ends `COMPLETED`. Zero OWs parked in
`waiting_for_settlement_account_replenishment`. One outlier, unrelated: OW 119442 completed offline 2026-02-03 and is
now `rejected` (events `…COMPLETED>FAILED`) — not investigated.
