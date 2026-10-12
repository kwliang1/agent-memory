<!-- machine-owned: regenerated every run, never hand-edit -->
---
concept: [treasury, transfer]
related:
  - [treasury, treasury_prime]
  - [treasury, outgoing_payment]
  - [treasury, customer_account]
---
symbols:  Transfer, Transfer::CreationError, Transfer::Request, Transfer::State, Transfers::CreateService, Transfers::FetchService, Transfers::IdempotencyTokenService, Transfers::InfoService, Transfers::Metadata, Transfers::Metadata::Direction, Transfers::Metadata::PaymentProcessor, Transfers::Metadata::PaymentType, Transfers::QueueingReason, Transfers::QueueingReason::Reason, Transfers::V2::BaseStateService, Transfers::V2::CreateService, Transfers::V2::Display::EnrichmentService, Transfers::V2::Display::EnrichmentService::SegmentRun, Transfers::V2::QueueingService, Transfers::V2::StateService
files:    app/models/transfer.rb, app/models/transfers/metadata.rb, app/models/transfers/queueing_reason.rb, app/services/transfers/create_service.rb, app/services/transfers/fetch_service.rb, app/services/transfers/idempotency_token_service.rb, app/services/transfers/info_service.rb, app/services/transfers/v2/base_state_service.rb, app/services/transfers/v2/create_service.rb, app/services/transfers/v2/display/enrichment_service.rb, app/services/transfers/v2/queueing_service.rb, app/services/transfers/v2/state_service.rb
indexed:  b9e45f71df9f1334507931a1f0b575bc976578a7
<!-- end machine-owned -->

## Judgment
Kevin's stated principle, not current code (nova#10090 merged with `PaymentTransfer.treasuryTransferId`): every outbound treasury movement (OutgoingWire, AchPush) should appear as a Transfer in nova; a nova payment record holding a raw treasury transfer id is a smell. See [[nova-10090-hand-reconciled-return]].
src: -Users-kevin-RubymineProjects/fddc5b46-aa1f-4487-9400-7921f3fb63c7.jsonl 2026-09-15T19:58:35Z "Any transfer in treasury (OutgoingWire, AchPush) should be represented in Transfer in nova as a principle.  this is a bad smell."
