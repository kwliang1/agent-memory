<!-- machine-owned: regenerated every run, never hand-edit -->
---
concept: [treasury, outgoing_wire]
related:
  - [treasury, treasury_prime]
  - [treasury, external_wire_account]
  - [treasury, transfer]
---
symbols:  OutgoingWire, OutgoingWire::State, OutgoingWire::State::Enum, OutgoingWires::CreateService, OutgoingWires::InfoService, OutgoingWires::Metadata, OutgoingWires::Metadata::CreateService, OutgoingWires::Metadata::Memo, OutgoingWires::Metadata::UpdateService, OutgoingWires::NotificationService, OutgoingWires::ObiWireInstructionService, OutgoingWires::StateService, OutgoingWires::SvbTagEntryGenerator
files:    app/models/outgoing_wire.rb, app/models/outgoing_wire/state.rb, app/models/outgoing_wires/metadata.rb, app/services/outgoing_wires/create_service.rb, app/services/outgoing_wires/info_service.rb, app/services/outgoing_wires/metadata/create_service.rb, app/services/outgoing_wires/metadata/memo.rb, app/services/outgoing_wires/metadata/update_service.rb, app/services/outgoing_wires/notification_service.rb, app/services/outgoing_wires/obi_wire_instruction_service.rb, app/services/outgoing_wires/state_service.rb, app/services/outgoing_wires/svb_tag_entry_generator.rb
indexed:  b9e45f71df9f1334507931a1f0b575bc976578a7
<!-- end machine-owned -->

## Judgment
OW books ledger entries up front. OP and Transfer behave like holds that stop counting once the movement completes, and Kevin calls OW's ledger model "weird"; it is part of why OP is replacing OW.
src: -Users-kevin-RubymineProjects/6ef9afda-9d7b-45b6-9970-d303d56f4cc8.jsonl 2026-09-24T20:54:01Z "OW is a ledger, but that's weird.  it should be a hold, and partially why it's being replaced by OP"
Cancel must not emit a duplicate Cancelled state-change event. A fix that only locked the refund's balance read was rejected because the losing pass still re-emitted Cancelled; #8987 locks the wire row instead. See [[outgoing-wire-cancel-webhook-race]].
src: -Users-kevin-RubymineProjects/c16ef544-9f6f-4819-91b7-504977e4f538.jsonl 2026-10-06T02:10:07Z "I do not want the dup event."
DIBS submission is a local call (~immediate), so the submit-vs-cancel claim state proposed after #8987 (`treasury_prime_submitting`, not built as of 2026-10-12) would be TP-only; DIBS is not affected.
src: -Users-kevin-RubymineProjects/68b09ed6-2a5c-4a87-9a13-f6fbd4fe2086.jsonl 2026-10-09T00:02:09Z "dibs is a local call, so it should be ~immediate"
src: -Users-kevin-RubymineProjects/68b09ed6-2a5c-4a87-9a13-f6fbd4fe2086.jsonl 2026-10-09T00:21:08Z "and that dibs is not affected"
