---
name: unprocessed-ach-return-overcredit
description: "Balance-check overcredit failure mode — bank returns an incoming ACH but Treasury never fires IncomingWire#return!, leaving a stuck-Provisioned wire whose balance inflates internal"
metadata: 
  node_type: memory
  type: project
  originSessionId: 1f9bc1bf-297d-48b3-8421-cd1bf75297a3
---

Confirmed 2026-07-09 (lark session) diagnosing CA 288810 "Cenas" overcrediting internal by exactly $13,499.

**Failure mode:** an incoming ACH (IAT) credit lands and Treasury provisions an `IncomingWire` (ledger: External Incoming Funds → IncomingWire, "Wire funds received", wire balance = +$amount), assigns it to a CA/sub-account — but the wire is never `Transferred`. Later the **bank returns the ACH** (TP account txn "RETURN INCOMING ACH CREDIT…", balance → $0), yet Treasury **never ingests that return** to fire `IncomingWires::StateService.return!`. The wire sits in `Provisioned` indefinitely holding a phantom balance.

`CustomerAccounts::BalanceService#incoming_wire_adjustment` (`balance_service.rb:124-126`) sums `incoming_wires.where(sub_account: active).sum(&:balance)` with NO state filter → the phantom balance is added to internal. Bank (TP) holds $0 → internal overcredited by the full wire amount. Flags every balance-check run as Unresolved; no In-Progress Adj (it's a V1 wire add-back, not V2/book).

**Concrete case:** IncomingWire 306566, $13,499, `Provisioned` since 2026-05-20, TP acct_11j3ks3h1c0cbv6: +$13,499 on 5/20 then RETURN −$13,499 on 6/5. Predates the July balance-check reworks (#8146/#8147 ~7/8) — matches Kevin's "predated recent changes."

**Immediate fix:** `return!` from `Provisioned` (`state_service.rb:245-259`) posts one reversing entry `IncomingWire → External Outgoing Funds` (category RETURN) and → `Returned`; wire balance $0; no cross-bank return transfer needed (funds never reached the CA). Admin "Return Wire" button does this.

**Systemic gap:** incoming ACH RETURNs on on-core GHB don't auto-drive the IncomingWire's `return!`. Confirmed in code: `AchPull`/`AchPush` have `mark_incoming_return!` (auto-fired when `IncomingAchFile` parses a return), but `IncomingWire` has NO equivalent. Same family as the incoming return/reversal holes in [[balance-check-gaps-discussion]] (relates to BANK-1594). Real money-truth reconciliation break, not just a check false-positive.

**Fix applied to 306566:** as of 2026-07-09 it is `returned` (ledger has the 5/21 credit + a 7/9 `IncomingWire→GlobalAccount#9` cat=RETURN entry); its sub's balance check is `naturally_resolved`. (Someone processed it between sessions.)

**Sweep done 2026-07-09 (lark) on prod read replica** via `al console create/exec -a treasury -e prod` + `rails runner`. Method: `IncomingWire.where(state:'provisioned').where.not(sub_account_id:nil)`, compute `.balance`, cross-ref `BalanceCheck::Record` latest-per-sub (internal `treasury_amount_cents` vs bank `external_amount_cents`). **3 confirmed siblings** — same signature (lone "Wire funds received" credit, no return entry, latest bc run shows external short of internal by EXACTLY the stranded balance): **306683** $5,904.78 (sub 178666, ext $0), **295427** $4,910 (sub 213716, ext $53.54), **295835** $970.47 (sub 220670, ext $924.66). Total $11,785.25. Fix each with `return!` from Provisioned (single reversing entry, no cross-bank transfer). Separate older tail exists: many 2023-24 provisioned WIRES ($5k–$12.5k) + a no-CA pair 201435/201323 = $1.64M on sub 378412 — different/older class, not the ACH-return mechanism; needs its own triage.
