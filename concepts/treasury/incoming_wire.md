<!-- machine-owned: regenerated every run, never hand-edit -->
---
concept: [treasury, incoming_wire]
related:
  - [treasury, treasury_prime]
  - [treasury, customer_account]
  - [treasury, bai2_sync_file]
---
symbols:  IncomingWire, IncomingWire::Direction, IncomingWire::PaymentType, IncomingWire::State, IncomingWires::AutoAssignService, IncomingWires::CreateService, IncomingWires::InfoService, IncomingWires::StateService, IncomingWires::UpdateService
files:    app/models/incoming_wire.rb, app/services/incoming_wires/auto_assign_service.rb, app/services/incoming_wires/create_service.rb, app/services/incoming_wires/info_service.rb, app/services/incoming_wires/state_service.rb, app/services/incoming_wires/update_service.rb
indexed:  b9e45f71df9f1334507931a1f0b575bc976578a7
<!-- end machine-owned -->

## Judgment
Kevin said, hedged, that the team judged auto-returning IncomingWires on a TP return (treasury#8202) overkill. Nothing was decided after, and [[project_bank1606_ach_return_webhook_unmerged]] says it starved for a reviewer, so treat the automation as unresolved. Before returning a `provisioned` credit by hand, confirm at the bank that the funds already went back; for DIBS programs `return!` checks this itself, so never pass `force: true` to get past it. See [[incoming-wire-return-automation-gap]].
src: -Users-kevin-RubymineProjects/31ca1194-49f4-46cd-a777-256bcb2c717b.jsonl 2026-09-29T23:39:15Z "I think we determined in a team call that it was overkill"
src: -Users-kevin-RubymineProjects/31ca1194-49f4-46cd-a777-256bcb2c717b.jsonl 2026-09-29T23:15:20Z "these should actually be returned, not stuck in provisioning"
