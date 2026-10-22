---
name: mmf-concurrent-sells-fee-leg-insufficient-funds
description: "Two+ open Frec MMF sells on one account deadlock settlement: the $45 MMF_SELL_FEES leg is validated against available_balance, which subtracts every sibling pending sell transfer"
metadata:
  type: project
---

`MoneyMarketFund::Sell#complete_sell_with_position_legs!` posts the gross `MMF_SELL` credit then a $45 `MMF_SELL_FEES` debit; the debit goes through `CustomerAccounts::ValidateBalanceService` against the MMF CA's `available_balance`. `pending_debit_amount` (balance_computation.rb ~121) subtracts all pending outgoing V2 transfers, including the sell transfers themselves. One sell nets to exactly $45 and passes `>=`; with N open sells the first to post sees the other N-1 nets as debits and fails `Origin has insufficient funds`. A code comment, "Not reserved cash: the position leg funding an MMF sell posts after the transfer starts", sits on a guard that only runs with `include_queued_transfers: false` and never for `processing` transfers.

Failure surface: `RefreshPendingOrdersActivity` (Sentry "Failed to refresh MMF Sell Order N" every 30 min) **and** the TP `incoming_wire.create` webhook, since `IncomingWireSyncService` calls the same method before completing the transfer. The wires sit at TP with no `IncomingWire` row and `TreasuryPrime::WebhookEvent` rows `errored`. Once Frec flips a liquidation to COMPLETE the refresh skips it (WIRE_PENDING-only), so the webhook is the only remaining path.

**Diagnose:** `ca.available_balance` on the MMF CA equals minus the sum of open sell nets; `TreasuryPrime::WebhookEvent.where(event_id: <iw ids>)` shows the validation error.

**Repair (write console):** in one transaction create all N `MMF_SELL` credits first, then the N fee legs, set each sell's `ledger_entry` and transition to `OrderCompleted`; then re-drive each wire with `IncomingWireSyncService.save_new_incoming_wire!`. The code fix adds `Transfer#mmf_sell_awaiting_position_legs?`, skips such transfers in `pending_debit_amount`, and gates the predicate on `Adapters::Base#funds_sell_from_position?`. Also seen: the IVA auto-refill for a second queued wire moved only cents, because the first refill was still queued and counted as a pending credit on the IVA (`transfer_funds_to_destination_if_necessary!`); untracked.

**Never set a repaired sell back to a refreshable state.** One repair flipped a sell back to `processing` and nil'd its `ledger_entry_id`, defeating the only idempotency guard (`return if ledger_entry_id.present?`), so the next refresh posted the legs again: −$45 NLV and phantom cash on the MMF CA. Check the sell's `ledger_entry_id` against the legs you created. Separately, Frec equity can move with no yield-feed event; those get hand-booked as backdated Yield rows.

Related: [[project_mmf-sell-balance-check-sla]], [[mmf-frec-uninvested-cash-drift]], [[treasury-three-balance-functions]].
