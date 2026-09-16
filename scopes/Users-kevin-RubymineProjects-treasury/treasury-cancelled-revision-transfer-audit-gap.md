---
name: treasury-cancelled-revision-transfer-audit-gap
description: Treasury audit-vs-revised balance mismatch failure mode — a cancelled/errored DESTINATION_CHANGE revision transfer leaves revised_destination written with no audit-side counter-entry
metadata:
  type: project
---

Recurring treasury failure mode found 2026-08-28 (Mehul's report on CA#278595/278597 "FBO Investors in Paytrack", audit ±$3,980,827 vs revised $0/$0).

`LedgerEntries::RevisionService.revise_ledger_entry_destination!` (`app/services/ledger_entries/revision_service.rb`) writes `revised_destination` on the original LE **synchronously**, but the audit-side counter-move is an **async Transfer** (`category=DESTINATION_CHANGE`, `metadata.revised_ledger_entry_id` set). If that transfer is cancelled/errored, nothing rolls back `revised_destination` and nothing recreates the transfer → the audit ledger is permanently long on one CA and short on the paired CA. Revised ledger and actual cash stay correct.

Verified facts:
- `IncomingWires::StateService#transfer!` mismatch branch fires when the wire's `original_sub_account` belongs to a different CA than `incoming_wire.customer_account` — typical when an LP wires to stale SVB coordinates for a fund now on Grasshopper.
- **Disbursement, investment vehicle and escrow** CAs own **zero** sub-accounts; `SubAccounts::InfoService.customer_account_with_sub_account` resolves them through the IVC to the CCA. **On-core is NOT one of them** — `InvestmentVehicleConfigurations::InfoService#for_customer_account_with_cca_sub_account` lists exactly `investment_vehicle_account_id, capital_collection_account_id, disbursement_account_id, escrow_account_id`; on-core keeps its own sub-account. (Kevin corrected me on this 2026-08-31 after I wrote the opposite in PR #8723.) For the three CCA-backed types both from_sub and to_sub land on the CCA, so the audit ledger for that CA can never balance from its own entries; on-core reassignments are genuine cross-owner moves.
- Ops workaround (seen 2026-06-01) creates same-CA `FUNDS_MIGRATION` chunk transfers with `revised_ledger_entry_id = nil` — moves the cash, contributes nothing to the audit ledger. The FUNDS_MIGRATION rows are the *fingerprint of the workaround*, not the bug.
- Kevin's #8611 (BANK-1849, merged 2026-08-20) fixes the trigger for the SVB >$1M case: `Transfers::InfoService.requires_svb_ach_split?` + `ach_split_amounts`. `Transfer#create_ledger_entry!` sets `revised_ledger_entry` with no amount-equality guard, so chunked revisions keep the audit link. It does NOT cover the general "revision transfer died" gap, and does nothing for existing residue.
- Blast radius query (2026-08-28): 12 non-completed DESTINATION_CHANGE revision transfers all-time, 35 CAs with audit != revised. Largest = CA#387770/387772 Etched.ai ±$22,585,906.88 (T#231498 errored 2026-08-17). Upekkha CA#327651/311974 still failing (T#240364 cancelled 2026-08-27) — an **on-core** case, so it has its own sub-account, takes the cross-owner path, and is NOT covered by the PR #8723 fix. Three diffs are just in-flight transfers and will close on their own.

**Why:** ops will keep reporting these as "balance mismatch" tickets; the answer is almost always "cash fine, audit ledger has a known gap." Related: [[funds-migration-autoforward-stranding]], [[svb-over-1m-wire-forward-8611]], [[incoming-wire-reassignment-stale-sub]], [[balance-check-gaps-discussion]].

**How to apply:** detector = transfer where `metadata.category='DESTINATION_CHANGE'` AND `metadata.revised_ledger_entry_id` present AND `state NOT IN (completed, in-flight)` AND the original LE still has `revised_destination` set AND `sum(LedgerEntry.where(revised_ledger_entry_id: orig))` != amount. Repair = write the missing audit-side DESTINATION_CHANGE entries; do NOT relax the `revised_only`/`not_*_migrations` scopes ([[feedback-repair-data-not-invariants]]).
