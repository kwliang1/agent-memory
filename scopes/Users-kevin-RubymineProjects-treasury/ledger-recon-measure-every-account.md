---
name: ledger-recon-measure-every-account
description: Ledger reconciliation target sets must include every account the plan writes, especially GlobalAccounts; GA#26 is the SVB sync anchor.
metadata:
  type: feedback
---

When building a treasury ledger reconciliation plan, the before/after measurement set must be
derived from the accounts the plan *writes*, not the accounts whose numbers you want to fix.

**Why:** On the Upekkha recon (2026-08) I built candidate E, hit all 8 self-chosen targets in a
rolled-back txn, and declared success. An adversarial reviewer found E moved `GlobalAccount#26`
+$198,300 in **both** audit and revised. It was in neither my baseline nor my result table — the
target set was drawn around the one account the plan damaged twice. Hitting every target proved
nothing because I picked the targets.

**How to apply:**
- Enumerate write targets first (every `origin`/`destination` on every new or repointed entry),
  then build the snapshot from that list. Never the reverse.
- Always snapshot the `GlobalAccount` on both sides. `global_account.rb:74-77`: EXTERNAL_INCOMING_FUNDS
  / EXTERNAL_OUTGOING_FUNDS "are only for accounting purposes and keep us in sync with SVB" — GA#26
  moving is a red flag, not a rounding detail.
- A revision entry whose destination isn't the exact mirror of the original silently relocates the
  discrepancy instead of clearing it. `set_as_revised_ledger_entry!` (`revision_service.rb:69-75`)
  enforces the mirror; hand-rolled `LedgerEntry.create!` recon entries bypass it.
- The real invariant is audit == revised, not "everything is zero." A nonzero balance that matches
  on both sides is an honest open signal; forcing it to zero usually means dumping it somewhere unwatched.
- Stale-sub-account check is `closed_at <= created_at` (`ledger_entries/sub_account_validation_service.rb:225`)
  — repointing an OLD entry to a later-closed sub does not trip it; only new entries do.

Related: [[treasury-cancelled-revision-transfer-audit-gap]], [[feedback-repair-data-not-invariants]]
