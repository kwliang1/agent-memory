---
name: duplicate-wire-debit-mismatch
description: "Balance-check mismatch class — a completed outgoing wire gets a SECOND CA→wire WITHDRAWAL ledger entry, over-debiting treasury internal (CA 313962 = $7,087.50)"
metadata:
  node_type: memory
  type: project
  originSessionId: 55f5576b-3a6c-4309-9a8f-44b9a9471694
---

Confirmed 2026-07-09 (moss session) on CA **313962** (Also Capital Management, LLC, a Management Company). Kevin asked if it was a *debit-card* mismatch that the recon project missed — **it is NOT: 0 card transactions on TP.** Real cause is a **duplicate outgoing-wire withdrawal**.

**Failure mode:** a normal completed outgoing wire has exactly **2** ledger legs: (1) `CustomerAccount → OutgoingWire` WITHDRAWAL (debits CA), (2) `OutgoingWire → GlobalAccount#21` (money actually leaves). Wire **116420** ($7,087.50) had a **3rd** leg — a SECOND `CA 313962 → OutgoingWire 116420` WITHDRAWAL (`le=5293492`, 2025-12-22) posted **6 days after** the wire already sent (`le=5283336`, 12-17). CA debited $14,175 for a wire that sent $7,087.50 once. TP shows the single real withdrawal (`wire_11mm3qcn7qkq7mf`) + a net-zero HOLD/Release pair. Net: treasury internal over-debited by exactly $7,087.50 → internal $15,932.45 vs TP $23,019.95. Persistent (24 failures/week), `In-Progress Adj: —`, `Checked==Current`. Clean comparison wire next to it: 112625 (2 legs, correct).

**Fix (write, not done):** correcting entry crediting CA 313962 $7,087.50 (Wire 116420 → CA, reversal/REFUND) → internal becomes $23,019.95 = TP, check clears.

**Open follow-ups:** (1) WHY the 12-22 second withdrawal posted for an already-completed wire (re-submission / double-book path) — if systemic, sweep completed outgoing wires having >1 `CA→wire WITHDRAWAL` leg. (2) Distinct mismatch class from the [[balance-check-gaps-discussion]] set (funds-migration, incoming-wire, holds) AND from the card-transaction recon (`Oncall::TreasuryPrime::CardTransactions::ResolutionService`, which only scans missing card *withdrawals* anyway). None of the existing recon tooling catches duplicate-wire-debit.

**How I verified (repeatable):** `al console exec -a treasury -p -- bundle exec rails runner <file>` (push file first with `al console push`). READ console lacks TP API config (`not an HTTP URI` at api_service.rb:78) — use `-w` write console for `TreasuryPrime::ApiService.get`; DB-only queries (LedgerEntry/OutgoingWire) work on read console. Key query: `ca.ledger.where(amount_cents: X)` + `LedgerEntry.where(origin: wire).or(LedgerEntry.where(destination: wire))` to count legs per wire. See [[treasury-prod-console-access]].
