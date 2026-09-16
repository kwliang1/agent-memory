---
name: reference_treasury_transfer_state_machine
description: Where the Treasury transfer state machine is documented + its authoritative Treasury-repo sources
metadata: 
  node_type: memory
  type: reference
  originSessionId: 5b7f6357-69d8-45dd-9507-dcfc1cd336aa
---

Treasury transfer state machine is documented in-repo at
`graph/src/clients/treasury/operations/transfers/README.md` (ASCII diagram + mapping).

Treasury owns the lifecycle; Nova observes the **simplified six-state** client enum
(`QUEUED, PROCESSING, COMPLETED, FAILED, RETURNED, CANCELLED`) via events + `getTransferDetails`.

Authoritative sources in the `treasury` repo (pass BOTH into review-gate agent context when
reviewing reconcile/state-machine changes):
- `app/models/transfer.rb` — internal `Transfer::State` enum + `typed_state_machine` transitions.
- `app/services/treasury_events/transfers/info_service.rb` — `mapped_state`: collapses all five
  internal machines (AchPull/AchPush/OutgoingWire/Transfer/IncomingWire) into the client enum;
  this is what `getTransferDetails` returns and what reconcile compares against.

Key gotchas: `COMPLETED` is NOT terminal (can still `RETURN`) — `isTerminalTreasuryState` excludes it.
Forward-only monotonicity holds only for INTERNAL transfers; e.g. IncomingWire `PendingReturn→PROCESSING`
occurs after `Transferred→COMPLETED`, so the unified view is not globally monotonic. See also
[[reference_treasury_batch_account_lookup]].
