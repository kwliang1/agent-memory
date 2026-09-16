---
name: tp-returned-wire-double-recognition
description: Treasury Prime returned wires get double-recognized — the rejection books a synthetic return and no dedupe exists against the real IncomingWire.
metadata:
  type: project
---

A rejected OutgoingWire on the **Treasury Prime** rail books its return TWICE.

1. Synthetic: `OutgoingWires::StateService#return_to_outgoing_wire_before_rejection!`
   (`app/services/outgoing_wires/state_service.rb:853-862`) writes
   `external_outgoing_funds -> outgoing_wire` (category DEPOSIT), then
   `return_to_customer_upon_cancellation!` (`:427-441`) writes `outgoing_wire -> customer_account`.
   Called from `reject!` (`:372-388`) on the `completed?` branch. Touches no bank.
2. Real: the bank credit arrives as an ordinary `IncomingWire` off the TP feed, hand-assigned to a
   CustomerAccount.

**The SVB path proves this is a bug, not the design.**
`app/services/svb/returned_outgoing_wires/assignment_service.rb:46` — `return false if original_wire.rejected?`
The system explicitly refuses to book a real return onto an already-rejected wire because the
rejection already booked one. It also never writes `external_outgoing_funds -> outgoing_wire`; the
credit enters on a separate `Svb::ReturnedOutgoingWire` contra-account and EXTERNAL_OUTGOING_FUNDS
keeps the full outflow permanently. `OutgoingWire#net_amount_transferred_externally`
(`app/models/outgoing_wire.rb:466-477`) treats credits from external_incoming_funds,
external_outgoing_funds, and Svb::ReturnedOutgoingWire as the same thing — **exactly one** should fire per wire.

`Svb::ReturnedOutgoingWire` is SVB/BAI2-only. `incoming_wires/auto_assign_service.rb` and
`create_service.rb` have ZERO references to OutgoingWire. No dedupe on the TP rail. This will recur.
Same neighbourhood as [[incoming-wire-return-automation-gap]] (BANK-1596/1598/1606).

**Repair:** `LedgerEntries::RevisionService.undo_ledger_entry!` on the synthetic
`external_outgoing_funds -> outgoing_wire` entry. Produces the swapped entry with
`revised_ledger_entry_id` set and zeroes the original. Guards: not itself a revision,
`revised_amount == amount`, nothing already revises it.

**Do NOT book the fee delta via `apply_late_return_fees!`** (`state_service.rb:393-414`) — a return that
arrives net of a fee already expresses it in the amount gap; charging again double-counts.

**Blast radius of moving a GlobalAccount:** the only bank-feed comparison is `check_ghb_omnibus!`
(`app/services/balance_checks/check_service.rb:41-79`), scoped to the GHB **Omnibus** program.
GHB On-core global accounts (GA#25/GA#26) are watched by nothing external.

Worked example: [[ikyam-incident-orphan-zeroings]]
