<!-- machine-owned: regenerated every run, never hand-edit -->
---
concept: [treasury, prophet_api]
related:
  - [treasury, ach_pull]
  - [treasury, ach_push]
  - [treasury, outgoing_payment]
---
symbols:  ProphetApi, ProphetApi::TraceDetailsService, ProphetApi::TraceDetailsService::Trace, ProphetApi::TransferDetailsService
files:    app/services/prophet_api/trace_details_service.rb, app/services/prophet_api/transfer_details_service.rb
indexed:  b9e45f71df9f1334507931a1f0b575bc976578a7
<!-- end machine-owned -->

## Judgment
Nova, not only venture, consumes treasury's paginated Prophet ledger endpoint (`LedgerEntries::PaginationService`), so count nova in the blast radius of any change there. Its running balances are cash-only, so MMF rows read about $0; Kevin deferred that fix to a follow-up. See [[treasury-prophet-ledger-consumed-by-nova]].
src: -Users-kevin-RubymineProjects/e1b43ac1-efc3-4110-be2c-6e4e0ccb787d.jsonl 2026-09-14T21:11:48Z "the prophet endpoint is consumed by nova"
