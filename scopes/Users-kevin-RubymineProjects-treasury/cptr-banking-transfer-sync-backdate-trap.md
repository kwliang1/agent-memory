---
name: cptr-banking-transfer-sync-backdate-trap
description: "Backdating a treasury LedgerEntry strands venture CPTR banking_transfers — cursor never re-delivers, create_or_find_by! never updates"
metadata: 
  node_type: memory
  type: project
  originSessionId: 8d4d73a3-c16d-4a73-874f-33fdab4675a6
  modified: 2026-09-09T18:36:16.433Z
---

Venture's CPTR fund-accounting sync (`CPTR::MembershipClasses::BankingService.sync_transfers!`, nightly via `AttributionService.process_all!` over every MembershipClass) pulls treasury's audit ledger through `bulk_transfers` with a uuid cursor. Treasury resolves the cursor to `(created_at, id)` and returns only entries strictly after it (`app/controllers/api/transfers_controller.rb:258`), so **backdating a treasury LedgerEntry can never be propagated by the sync**:

- Already-synced CPTR copy: `create_or_find_by!` (banking_service.rb:57) never updates → `transfer_created_at` stays stale. CPTR as-of windows key on `transfer_created_at` (categorization_service.rb:231), so fund-accounting closes don't see the backdate.
- Not-yet-synced entry: falls behind every fund's cursor → skipped forever. Delete-and-resync also can't re-ingest (same cursor math).

Correct runbook for any treasury created_at backdate: BEFORE backdating, ensure all affected uuids are already ingested per fund (`sync_transfers!` if missing); AFTER, patch `transfer_created_at` in place on venture console, plus any attribution `effective_at`/GL `effective_datetime` (stamped from transfer_created_at at creation, attribution_service.rb:50). Only DA/CCA/IVA/ONCORE accounts sync (`treasury_account_ids_for_fund_accounting`); entries entirely within one fund's own account set are excluded (`exclude_transfers_within_input_accounts: true`).

Verified for PR #8809 (prod, 2026-09-09): six of the seven repair entries never enter the feed (five within-fund CCA→DA / on-core→CCA, one no-CA leg); the ONE synced copy is `CPTR::BankingTransfer b986841edfc24606b783bea10eed55d9` (Upekkha MC 9050282e…, LE 5839105, −$198,300, 0 attributions) — post-run patch its transfer_created_at to 2026-08-06 21:48:47 UTC. It is also that fund's sync cursor; the rewind re-scan is harmless (uuid dedupe). Related: [[treasury-point-in-time-balances-created-at]].
