---
name: tp-wire-transfers-frec-uuid-ids
description: transfers_metadata rows with initiating_payment_processor=treasury_prime + payment_type=wire include Frec MMF rows whose processor id is a UUID, not a TP wire_ id — any TP lookup over that set must filter on the wire_ prefix
metadata:
  type: reference
---

Prod 2026-11-05 (BANK-2379): of 414 TP-processor wire `transfers_metadata` rows, 133 had UUID `initiating_payment_processor_transfer_id`s (132 Frec Money Market Fund, 1 GHB Main) — TP 404s on them. Filter `initiating_payment_processor_transfer_id LIKE 'wire\_%'` before calling `TreasuryPrime::OutgoingWires::InfoService.details`. Kevin: "we should skip frec".

Also: TP wire GET returns `imad.unparsed` but omad nil for cross-bank Transfer wires; DIBS-started Transfer wires keep IMAD on `DIBS::WireMetadata` (`DIBSApi::PaymentTransfersService.wire_trace`). One candidate row (338996) fails current Transfers::Metadata validation (force_note without force_reason) — backfills over metadata must not use `update!`.

`gh stack submit --auto` creates the PRs as drafts.
