---
name: incoming-ach-unledgered-recon
description: "How incoming ACH credits get ledgered (webhook-only), why they silently go missing, and how to diagnose/remediate an unledgered credit"
metadata: 
  node_type: memory
  type: reference
  originSessionId: 8b6d1ebb-a51a-4edc-a1df-f88118df876b
  modified: 2026-08-19T20:28:18.544Z
---

Incoming ACH **credits** (TP ids `inach_`/`ttx_`) are reconciled into Treasury as an **`IncomingWire`** (model handles ACH too, `payment_type: Ach`), created **only** by the TP `account.update` webhook → `TreasuryPrime::WebhookService` (`webhook_service.rb:95`) → `AchSyncService.save_new_incoming_ach_push_transactions_and_manually_applied_wires!`. Lifecycle: `created → provisioned` (credits IncomingWire holding acct) `→ transferred` (posts LedgerEntry to the customer account; gated by `IncomingWires::InfoService.should_auto_transfer_incoming_wire?` — originator-name Jaro-Winkler match, prohibited-country, FBO). `ttx_` is stored in `IncomingWire.treasury_prime_wire_id`.

**Silent-miss failure mode (seen 2026-08, INC/one-off for acct 454313 Yi Cheng Chang):** if the `account.update` webhook is dropped (`treasury_prime.webhook_dropped` is nonzero in prod), the credit is NEVER ingested — no IncomingWire, no ledger credit — money sits at the bank. The designed backstop (`treasury_prime:sync_incoming_achs` rake → cursor-based `IncomingAchs::SyncService`) was **NOT running** (no `IncomingAchSyncer` cursor row; `treasury_prime.incoming_ach_sync.*` metrics absent 30d), so nothing self-heals.

**Diagnose (read console, `al console exec -a treasury -p -- bin/rails runner`):**
- `BalanceCheck::Record.where(sub_account_id: X).order(checked_at: :desc)` → `external_amount_cents` (bank) vs `treasury_amount_cents` (ledger); persistent gap = unledgered. This is the mirror to use since **read console can't reach the TP API** ("not an HTTP URI").
- Cohort of current unexplained incoming gaps: latest `run_uuid`, `where('external_amount_cents > treasury_amount_cents').where(resolution_status: [nil,''])` (blank status = unresolved; `expected_to_settle`/`naturally_resolved`/`auto_resolved` are fine). `.past_critical` statsd fires past SLA.
- Confirm truly missing: check `IncomingWire.treasury_prime_wire_id`, `CrossTransfer.incoming_treasury_prime_wire_id`, `AchExternalDebit`, `Transfers::Metadata.receiving_payment_processor_transfer_id`, and `TreasuryPrime::WebhookEvent.where(event_id: 'acct_...')` (account.update delivery history).

**Two rails, two backstops — both were down (2026-08-19):**
- **ACH credit:** real-time `account.update` webhook → `AchSyncService.save_new_incoming_ach_push_transactions_and_manually_applied_wires!`. Backstop `TreasuryPrime::IncomingAchs::SyncService.sync_missing_incoming_ach_records_batch!` (cursor `IncomingAchSyncer`) — was NOT running (no cursor row, no `incoming_ach_sync.*` metrics in 30d).
- **Wire credit:** real-time **`incoming_wire.create`** webhook → `IncomingWireSyncService.save_new_incoming_wire!(treasury_prime_wire_id: 'iw_...')`. NOTE the `account.update`/ACH handler does NOT reconcile normal incoming wires (only ACH + manually-posted wires). Backstop `TreasuryPrime::IncomingWires::SyncService.sync_missing_incoming_wire_records_batch!` (cursor `IncomingWireSyncer`) — was frozen ~9 days (stuck at 2026-08-10). Real-time webhooks carry normal volume on both rails, so a dropped webhook (ACH or wire) goes unrecovered → standing cohort of unledgered credits.
- `treasury_prime.webhook_dropped` = handler **raised** (controller `treasury_primes_controller.rb:100`), i.e. arrived-but-errored — NOT proof of non-delivery. A truly missed webhook leaves NO `TreasuryPrime::WebhookEvent` row at all.

**Remediate (WRITE — Kevin runs; all idempotent, early-return on already-reconciled ids):**
- ACH: `AchSyncService.save_new_incoming_ach_push_transactions_and_manually_applied_wires!(treasury_prime_external_account_id: 'acct_...')` — creates IncomingWire, provisions, auto-transfers if name-match passes; else stops in `provisioned` needing Flowdash assignment.
- Wire (needs the `iw_` id from TP dashboard / admin ledger pending row — read console can't reach TP API): `TreasuryPrime::SubAccounts::IncomingWireSyncService.save_new_incoming_wire!(treasury_prime_wire_id: 'iw_...', treasury_prime_instance: TreasuryPrime::Instance.find_by!(name: 'main'))`.
- Sweep (discovers missing + unsticks cursor), dry_run:true first: `TreasuryPrime::IncomingWires::SyncService.sync_missing_incoming_wire_records_batch!(...)` and `TreasuryPrime::IncomingAchs::SyncService.sync_missing_incoming_ach_records_batch!(...)`.
Systemic fix: get both backstops scheduled/running again. See [[al-console-access]].
