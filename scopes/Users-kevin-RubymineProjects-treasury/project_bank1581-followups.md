---
name: bank1581-followups
description: "BANK-1581 RCA outcomes and the three follow-up issues worth filing (DIBS return gap, ACH auto-transfer, reconcile_transfer_v2 amount-matching)"
metadata: 
  node_type: memory
  type: project
  originSessionId: 44bb6bfd-0226-4aa0-9869-657ad1d53a41
---

BANK-1581 (2026-07-08): the "webhook never created an IncomingWire" premise was wrong — the DIBS webhook worked; ops manually returned wire #307492 from `provisioned`, a **ledger-only** branch of `IncomingWires::StateService.return!` that moves no money at the bank. Fix: PR #8128 (Maintenance::ReledgerReturnedIncomingWireTask, re-provision + transfer).

Unfiled follow-ups discovered (verify code still matches before citing):
1. `return!` on a provisioned/created wire for DIBS-backed programs silently diverges Treasury from the bank — no bank-side return is triggered or required.
2. DIBS incoming ACHs can NEVER auto-transfer: `should_auto_transfer_incoming_wire?` requires non-nil `originator_country`, which DIBS ACH metadata never sets — every DIBS ACH lands in the manual ops queue.
3. `reconcile_transfer_v2` (TreasuryApp::NotificationService) matches incoming DIBS payments to pending transfers by **amount only** — genuine external deposits can be consumed as internal-transfer reconciliation (suspected on CAs 229551, 454945, 455957; ~15 DIBS accounts had live mismatches in the 2026-07-07 balance-check run).

Sweep facts: 603 wires ever returned-on-Treasury-while-DIBS-completed; only George's had a live mismatch equal to the wire amount. Related: [[prod-query-local-verify]].
