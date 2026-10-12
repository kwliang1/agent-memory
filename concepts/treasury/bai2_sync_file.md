<!-- machine-owned: regenerated every run, never hand-edit -->
---
concept: [treasury, bai2_sync_file]
related:
  - [treasury, incoming_wire]
  - [treasury, transfer]
  - [treasury, bai2_previous_day_sync_file]
---
symbols:  Bai2SyncFiles::AchProcessingService, Bai2SyncFiles::OtherProcessingService, Bai2SyncFiles::ProcessingService, Bai2SyncFiles::WireProcessingService
files:    app/services/bai2_sync_files/ach_processing_service.rb, app/services/bai2_sync_files/other_processing_service.rb, app/services/bai2_sync_files/processing_service.rb, app/services/bai2_sync_files/wire_processing_service.rb
indexed:  b9e45f71df9f1334507931a1f0b575bc976578a7
<!-- end machine-owned -->

## Judgment
Only SVB syncs through BAI2. The DIBS direct-bank programs (Piermont Direct, BNY, JPM, Increase GHB) do not, so a finding that assumes their incoming wires arrive in a BAI2 file is wrong.
src: -Users-kevin-RubymineProjects/f6ab7459-014a-4f5f-94ab-9e0ba459bb03.jsonl 2026-10-07T00:09:11Z "this is also incorrect. only SVB sync via bai2"
An ACH credit into the SVB concentration account becomes a provisioned IncomingWire during BAI2 processing, so an unledgered raw-TP true-up there mints orphan wires. Kevin wants any money move that skips the ledger adversarially checked before it is proposed. See [[project_terran-robotics-wire-omnibus-shortfall]].
src: -Users-kevin-RubymineProjects/d8ffa40b-2dd8-4b70-8196-17ccacc9ca7e.jsonl 2026-09-25T18:27:08Z "since this moves money unledgered, and is difficult to undo, can you adversarially check it one more time?"
