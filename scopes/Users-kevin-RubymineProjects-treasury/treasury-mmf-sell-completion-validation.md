---
name: treasury-mmf-sell-completion-validation
description: "Transfer can't enter Completed without initiating_payment_processor_transfer_id; PR #8378 removed the only writer on the MMF sell path (2026-07-28), arming a latent failure where the position leg commits and the cash leg rolls back."
metadata: 
  node_type: memory
  type: project
  originSessionId: 1a88ecdb-da63-4f54-b22e-a372bec5eacc
  modified: 2026-07-31T06:28:05.113Z
---

`Transfer::STATES_REQUIRING_INITIATING_PP_TRANSFER_ID` includes **`Completed`** (`transfer.rb`), and `transition_to!` is an `update!`, so validations run. A transfer with a nil `initiating_payment_processor_transfer_id` **cannot complete** — it raises `ActiveRecord::RecordInvalid: "Initiating payment processor transfer must be present when state is submitted or beyond"`.

**The MMF sell trap.** `IncomingWireSyncService`'s MMF intercept calls `mmf_sell.complete_sell_with_position_legs!` (own `with_lock`, **commits**) *before* `Transfers::V2::StateService.complete!`. Neither caller wraps it in a transaction, so if `complete!` raises the position leg stays posted and the cash leg rolls back: holdings reduced, cash never ledgered, no `IncomingWire` row. Arrives via a TP webhook (`treasury_primes_controller.rb`, `incoming_wire.create`), and `complete_sell_with_position_legs!` is idempotent on `ledger_entry_id.present?`, so the leg posts once and every retry re-raises.

**History that matters:** from the V2 cutover (`a20abc52b`, 2026-07-01) until **PR #8378 (`1692daccd`, 2026-07-28)**, `sell!` wrote the FREC liquidation id into that column, so all sells completed fine (prod: 131 completed, all populated). #8378 deleted that one line — correctly, because a FREC UUID in a TP-named field made `TreasuryPrime::Transfers::ReconciliationService` poll TP with FREC ids (TREASURY-66T, ~44 events/day). It didn't notice the field was load-bearing for completion. **Latent, not fired** — prod had zero in-flight sells when checked.

**Why BANK-1595 resolves it properly:** `reconciliation_service.rb:60` filters `initiating_payment_processor: 'treasury_prime'`, so once the sell's initiating processor is `frec` the transfer drops out of the TP poller regardless of that column — making the write safe again. Don't re-delete it.

**Diagnostic for "did this fire":** `MoneyMarketFund::Sell` in `wire_completed` whose `transfer` is not `completed` is the exact fingerprint (position leg posted, completion failed). Worth a standing monitor.

**Spec trap:** the one spec covering that path stubbed `complete!` with a message expectation, so the transition never executed and CI stayed green. When testing a wire-matching path, don't stub the thing that actually transitions.

See [[treasury-enum-value-ci-and-rollback]].
