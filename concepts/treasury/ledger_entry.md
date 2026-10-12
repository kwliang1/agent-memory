<!-- machine-owned: regenerated every run, never hand-edit -->
---
concept: [treasury, ledger_entry]
related:
  - [treasury, fund]
  - [treasury, customer_account]
  - [treasury, transfer]
---
symbols:  LedgerEntries::FetchService, LedgerEntries::InfoService, LedgerEntries::PaginationService, LedgerEntries::PaginationService::Page, LedgerEntries::RevisionService, LedgerEntries::SubAccountBackfillService, LedgerEntries::SubAccountValidationService, LedgerEntries::UpdateService, LedgerEntry
files:    app/models/ledger_entry.rb, app/services/ledger_entries/fetch_service.rb, app/services/ledger_entries/info_service.rb, app/services/ledger_entries/pagination_service.rb, app/services/ledger_entries/revision_service.rb, app/services/ledger_entries/sub_account_backfill_service.rb, app/services/ledger_entries/sub_account_validation_service.rb, app/services/ledger_entries/update_service.rb
indexed:  b9e45f71df9f1334507931a1f0b575bc976578a7
<!-- end machine-owned -->

## Judgment
Audit balances must equal revision balances; a gap is data to reconcile, not a metric that "isn't revision-aware". A DCR that set `revised_amount` with no revising entry (`revised_by = []`) is an orphan zeroing: the repair (with Kevin's go-ahead) is LedgerEntry changes so everything nets to zero. See [[ikyam-incident-orphan-zeroings]].
src: -Users-kevin-RubymineProjects/b6523e00-a23e-476e-a33b-16329f7f4c79.jsonl 2026-08-31T22:13:22Z "we established that audit balances should equal the revision balances"
src: -Users-kevin-RubymineProjects/b6523e00-a23e-476e-a33b-16329f7f4c79.jsonl 2026-08-31T23:37:35Z "I want a solution that include LedgerEntry manipulation tog et everything zeroed out"
Backdated ledger repairs: check how CPTR carries the date onto the GLE, and draft a message to finance for Kevin to send before running. See [[cptr-banking-transfer-sync-backdate-trap]].
src: -Users-kevin-RubymineProjects/be4e251e-115c-4186-9f17-f423486ec763.jsonl 2026-10-09T00:24:00Z "a consideration for cptr and how it handles it on the GLE"
src: -Users-kevin-RubymineProjects/a6757cf9-f11c-4de2-a6cf-50a0dcc3b508.jsonl 2026-10-09T00:38:01Z "draft a message to the finance team before I run it"
