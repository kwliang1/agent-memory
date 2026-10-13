---
name: cptr-banking-transfer-sync-backdate-trap
description: "Backdating a treasury LedgerEntry strands venture CPTR banking_transfers — cursor never re-delivers, create_or_find_by! never updates; 8809 run 9/17, one venture row left"
metadata: 
  node_type: memory
  type: project
  originSessionId: 8d4d73a3-c16d-4a73-874f-33fdab4675a6
  modified: 2026-09-17T17:11:14.914Z
---

Venture's CPTR fund-accounting sync (`CPTR::MembershipClasses::BankingService.sync_transfers!`, nightly via `AttributionService.process_all!`) pulls treasury's audit ledger through `bulk_transfers` with a uuid cursor resolved to `(created_at, id)`, returning only entries strictly after it (treasury `app/controllers/api/transfers_controller.rb:258`). So **backdating a treasury LedgerEntry can never propagate through the sync**: an already-synced copy keeps its stale `transfer_created_at` (`create_or_find_by!`, banking_service.rb:57, never updates), and a not-yet-synced entry falls behind every cursor forever (delete-and-resync can't re-ingest either). CPTR as-of windows key on `transfer_created_at` (categorization_service.rb:231). Runbook: BEFORE backdating ensure affected uuids are ingested per fund; AFTER, patch `transfer_created_at` in place on a venture console plus any attribution `effective_at`/GL dates (stamped at creation, attribution_service.rb:50). Only DA/CCA/IVA/ONCORE accounts sync, and entries within one fund's own account set are excluded (`exclude_transfers_within_input_accounts: true`).

Treasury PR #8809 (backdate the 7 audit-gap repair entries, LE 5836098–100 + 5839103–06): merged and **run by Kevin 2026-09-17 16:56 UTC (MaintenanceTasks::Run 81, succeeded)** — all 7 verified matching their revised entries' created_at, audit−revised = $0 at the as-of instants. Six of seven never enter the CPTR feed (within-fund or no-CA leg). **OPEN as of 2026-09-17:** the ONE synced copy `CPTR::BankingTransfer b986841edfc24606b783bea10eed55d9` (Upekkha MC 9050282e…, LE 5839105, −$198,300, 0 attributions) still has `transfer_created_at=2026-09-01 23:21:25 UTC`; needs `update!(transfer_created_at: Time.utc(2026,8,6,21,48,47))` on a venture write console. It is also that fund's sync cursor — the rewind re-scan is harmless (uuid dedupe). Related: [[upekkha-ikyam-wire-reconciliation]].
