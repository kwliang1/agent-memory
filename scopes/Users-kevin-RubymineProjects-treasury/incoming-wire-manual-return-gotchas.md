---
name: incoming-wire-manual-return-gotchas
description: Treasury manual IncomingWire return — transition_to! does NOT fire the Prophet event; StateService.return! pending_return branch requires return_transfer
metadata: 
  node_type: memory
  type: reference
  originSessionId: 40c26f3f-ef83-4a11-b444-f9c18bb5f357
  modified: 2026-07-29T05:34:27.996Z
---

Manually marking an IncomingWire `Returned` (e.g. INC-5326 penny-wire cleanup):

- **`transition_to!(state)` is bare** (`typed_state_machine_v2.rb:66`): checks `can_transition?` then `update!(state_column => ...)`. It does NOT emit the Prophet `TreasuryEvents` state-change event and does NOT call the transition's `method:` (StateService). Any snippet that says "transition_to! fires the Prophet event" is WRONG. You must call `w.create_state_change_event!(TreasuryProphetApi::Messages::Transfer::State::Returned)` yourself (that's what `IncomingWires::StateService.return!` does right before the transition).
- **`StateService.return!` can't be used for unassigned/weird wires**: its `pending_return?` branch hard-raises if `return_transfer` is nil. Unassigned incoming wires (no customer_account/sub/return_transfer) have none → must return manually. Its `provisioned?` branch is the template Taylor's INC-5326 snippet copies: `LedgerEntry.create!(origin: wire, destination: GlobalAccount.external_outgoing_funds(partner_bank_program:), category: RETURN, amount_cents:, from_sub_account: wire.original_sub_account)` then create_state_change_event! + transition_to!.
- **`from_sub_account: nil` is fine** when the wire holds the balance directly (sub_account_id nil) — origin=wire → EXTERNAL_OUTGOING_FUNDS (GlobalAccount#2) zeroes the wire's own balance. GlobalAccount#1=EXTERNAL_INCOMING_FUNDS, #2=EXTERNAL_OUTGOING_FUNDS.
- **Always wrap the loop in `ActiveRecord::Base.transaction`** and guard `unless w.pending_return?`. The naive `.each { LedgerEntry.create!; transition_to! }` commits the ledger entry BEFORE the transition; if the wire is already `returned`, `can_transition?(Returned)` is false → raises AFTER an orphaned RETURN ledger entry is committed = balance corruption.
- Verify wire *current* state before running any batch snippet — lists in Slack go stale (INC-5326: 2 of 4 wires were already returned days later).

Related: [[incoming-wire-return-automation-gap]], [[bai2-ach-debit-attribution]], [[treasury-prod-console-access]].
