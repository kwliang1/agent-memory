---
name: reference_complete-else-branch-no-ops-by-design
description: "TreasuryPrime::Transfers::StateService#complete!'s else branch legitimately no-ops for rejected/cancelled wire refunds — do not add a raise or alert there"
metadata:
  node_type: memory
  type: reference
---

`app/services/treasury_prime/transfers/state_service.rb#complete!` ends with:

```ruby
if transfer.origin.is_a?(OutgoingWire)
  if replenishing_international_settlement?(transfer)
    OutgoingWires::StateService.complete_offline_wire!(outgoing_wire, override_amount: ...)
  else
    OutgoingWires::StateService.mark_as_treasury_prime_offline_processing!(outgoing_wire)  # may return false
  end
```

`mark_as_treasury_prime_offline_processing!` returns **false silently** when the wire has no edge to
`treasury_prime_offline_processing` (only `treasury_prime_ready_to_submit` and
`waiting_for_backing_wire` have one — `app/models/outgoing_wire.rb`). `complete!` is
`sig { ... .void }`, so the false is discarded.

**A BANK-2149 reviewer asked for a raise / `ErrorTracker.critical` there**, to surface a narrow race
where a cross transfer completes but the wire moves neither way. Declined, with evidence: the same
`complete!` creates the excess/rejected refund at `transfers/state_service.rb:168-174` —
`origin: outgoing_wire, destination: outgoing_wire.customer_account` — and **when that refund
completes it takes this exact else branch with a `rejected` or `cancelled` wire**. So the false
return is a routine, correct outcome on a live path. An alert there would fire on every refund of a
rejected or cancelled wire.

If the silence ever does need fixing, the fix is to narrow the condition to the shapes where a
no-op is genuinely wrong, not to alert on the branch. Related:
[[feedback_minimal-change-in-review-gate]].
