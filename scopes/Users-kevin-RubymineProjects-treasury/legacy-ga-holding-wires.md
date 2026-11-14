---
name: legacy-ga-holding-wires
description: Wires still held in legacy HOLDING_ACCOUNT_FOR_INCOMING_WIRES GlobalAccounts hold real cash; release/return traps
metadata:
  type: project
---
Six GlobalAccount holding accounts (GA 45/46/47/48/54/55) each have an active sub-account, so their ledger balance is real bank cash. New holds go to `CustomerAccount.holding_account` instead; only legacy-held wires (9 as of 2026-10-29, ids 155722 196487 208912 211204 212059 214740 217992 239187 243898) release out of a GA.

**Why:** #6675 made GA-side destination revisions ledger-only, stranding cash at the bank on release (LE 5965404, 5619130 — both repaired). PR treasury#9320 (BANK-2467) books the leg again.

**How to apply:**
- All 9 have `original_sub_account_id` nil, so `return!` raises for them; any release-then-return sequence in one transaction can book at TP then roll back.
- `IncomingWire#active_sub_account` exists (incoming_wire.rb:287) — never gate "real money" on `.try(:active_sub_account)` alone.
- GA 46 ledger = TP = $22,437.02 but its held wires total ~$268k; releasing 155722 ($26.7k) fails on insufficient funds regardless.
