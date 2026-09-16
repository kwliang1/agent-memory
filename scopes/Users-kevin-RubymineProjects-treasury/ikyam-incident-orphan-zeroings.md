---
name: ikyam-incident-orphan-zeroings
description: Upekkha/IKYAM Aug-2026 incident — rejected wire return booked twice; three orphan zeroings are the whole audit/revised gap.
metadata:
  type: project
---

Upekkha on-core (CA#327651) / fund (CA#311974) reconciliation, worked 2026-08-31.

**The incident:** six $198,300 wire attempts to IKYAM AI PRIVATE LIMITED, 2026-08-06 → 08-12.
Only `OW#134107` succeeded (`completed`, out 08-13, never returned). `OW#133677` was `rejected`.

**Root of the audit/revised gap:** the rejected wire's return was booked twice —
synthetically as LE#5796128 (`GA#26 → OW#133677`) + LE#5796129 (`OW#133677 → CA#327651`), and for
real as `IncomingWire#317372` $198,250 (LE#5796211/5796321). IW#317372's originator is IKYAM and
originator bank is Standard Chartered — same as OW#133677's beneficiary. The $50 delta is the wire fee.
Zeroing LE#5796129 to kill the duplicate was CORRECT (Kevin said so; verified). Do not restore it.

**The real defect — orphan zeroings.** `revised_amount_cents = 0` with NO revising entry:
LE#5796129, LE#5804886, LE#5816291. 3 × $198,300 = $594,900 = exactly CA#327651's
audit-minus-revised gap. Contrast properly-paired zeroings LE#5805276 (revisers=[5816164]) and
LE#5801917 (revisers=[5803144, 5816165]). LE#5796128 was never zeroed at all — the other half of
the phantom pair — which is why OW#133677 read audit $0 vs revised $198,300.

**THE ANCHORING ERROR (the key lesson).** On-core sub SA#403357 reads `ledger_balance` $396,096.65 but
`full_internal_balance` $0.00 and BANK $0.00 — diff $0, green the whole time. `ledger_balance` is
revision-blind and reconciled against NOTHING. I anchored the fund to a bank figure but derived
on-core's target from the ledger, then treated my own derivation as truth. That manufactured a
"-$198,300 hole" and a "one transfer too many was zeroed" theory. Both were artifacts; there is no hole.
Always pull `SubAccounts::BalanceService.external_balance(sa)` for EVERY account in the target set
before setting targets. See [[treasury-three-balance-functions]].

**PLAN L-final (verified, all targets met).** Four entries:
- sub-neutral mirrors (BOTH legs on 403357) completing orphans LE#5804886, LE#5816291, LE#5796129
- `LedgerEntries::RevisionService.undo_ledger_entry!` on phantom LE#5796128
Result: CA#311974 $57,878.79, CA#327651 $0, OW#133677 $0 (stranded $198,300 cleared), GA#25 unchanged,
GA#26 +$198,300 — all audit == revised. SA#403357 internal $0 == bank $0 (stays green),
SA#513688 $57,878.79 == bank. No balance check moves.

GA#26 move independently reviewed and confirmed — see [[tp-returned-wire-double-recognition]].
Gating check: only IW#317372 has originator IKYAM/Standard Chartered; IW#317808 and IW#318125 have
BLANK originators, so they are not returns of this wire.

**EXECUTED 2026-09-01.** Kevin ran it; verified in prod. Four entries written:
LE#5839103 (revises 5804886), LE#5839104 (revises 5816291), LE#5839105 (revises 5796129),
LE#5839106 (revises 5796128, via `undo_ledger_entry!`). All four sources now zeroed AND paired.
Final: CA#311974 $57,878.79, CA#327651 $0, OW#133677 $0, GA#26 $89,685,973.48 — all audit == revised.
SA#513688 and SA#403357 both internal == bank, diff $0. Four nova outbox rows published
(treasury-events-publish-1326667..1326670) — do NOT suppress `emit_treasury_event` on recon writes;
it is a transactional outbox row that rolls back safely, and suppressing hands nova a permanent divergence.
Re-run blocked on all four (guard = `LedgerEntry.where(revised_ledger_entry_id: id).exists?`).

**Open (business, not ledger):** CA#314575 (parallel fund) advanced $198,300 on 08-04 (LE#5790802);
the return was assigned to CA#311974, which funded the wire that went out. Whether that needs
unwinding depends on whose investment IKYAM is. Ledger is consistent either way.

**Still open from the RCA:** the half-pair detector (zeroed revised_amount with no offsetting entry),
and filing the TP returned-wire dedupe gap.

Related: [[ledger-recon-measure-every-account]], [[upekkha-oncore-reconciliation-state]], [[treasury-three-balance-functions]], [[tp-returned-wire-double-recognition]]
