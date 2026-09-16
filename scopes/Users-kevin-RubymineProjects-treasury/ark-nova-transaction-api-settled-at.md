---
name: ark-nova-transaction-api-settled-at
description: Nova→Ark bank Transactions API needs a per-txn settlement/posting date; treasury only has a bank-true value date for SVB wires — a real sourcing gap.
metadata: 
  node_type: memory
  type: project
  originSessionId: a5b06fab-d416-4f15-9f99-8ffbd7b7b600
  modified: 2026-08-24T06:52:34.194Z
---

Nova→Ark "Bank Account / Transaction APIs" (Notion 3a661e866662806ba012cd7dd166193a, Nova Roadmap Q3'26-C2, "Ark Integration"; Linear project bank-account-transaction-apis-7a3154eee01e). Ark ingests Nova bank txns to build journal entries; only wants Settled/Completed rows. Spec's transaction object has a single `created_at` (typed datetime, example is midnight-UTC = really a date).

**Katie's requirement (challenge premise):** needs explicit `settled_at`/`posted_at` = bank posting/value date (drives accounting period; wire created 8/29 settles 9/2 → wrong month). Accounting logic sound; premise that treasury *holds* that date is largely FALSE.

**What treasury actually has (verified 2026-08-23, treasury/main):**
- OutgoingPayment.completed_at = `execution.completed_at` (`outgoing_payment.rb:613`); real col on `outgoing_payment_executions`, set `Time.current` when bank_state→Completed (`outgoing_payment/execution.rb:346`). = our processing clock, not bank value date. **Semantics DIVERGE by processor** (`BANK_STATE_MAP` :275 maps BOTH `'completed'` AND `'sent'`→Completed): SVB path (`bai2_sync_files/wire_processing_service.rb:224`) fires on BAI2 statement = true settlement; **TP path (`treasury_prime/webhook_service.rb:545`) fires on tp_status `sent` = final-leg DISPATCH to Fed, not beneficiary settlement**, stamped our clock; Completed is terminal so a later real TP `completed` can't re-transition (stays pinned to `sent`). DIBS (`notification_service.rb:227`) file/confirmation-driven, closer to settlement (not fully verified). → As Nova rides more TP volume, completed_at drifts to "when we saw it sent" — wrong anchor for accounting period.
- OutgoingWire.completed_at = computed method (`outgoing_wire.rb:493`), NOT a column: `bai2_account_sync_file.file_date` (`.prev_weekday` for wires ≥2017-09-18). TRUE bank posting date — but **SVB-only**: file attached only by SVB BAI2 path (`bai2_sync_files/wire_processing_service.rb`, Processor::Svb). TP/GHB/Piermont wires complete via webhook (`notification_service.rb:388`) with NO file → completed_at == nil. Migrating off SVB → goes null.
- AchPush: NO completed_at/settlement col at all. Completion = `complete` event via BAI2/webhook; `AchPushes::StateService.complete!` (`ach_pushes/state_service.rb:144`) just flips state + ledger entry. Best proxy = completing LedgerEntry.created_at (immutable, unlike updated_at) but still processing clock.

**Kevin's two correct pushbacks:** (1) OW doesn't always have a BAI2 file (nil for non-SVB). (2) AchPush isn't a single `push→external` edge — multi-leg graph: mirror pull mirror→CA (`state_service.rb:246`), provision CA→push (:108), complete push→external (:149), shared-acct external bump (:158). Ark spec groups one movement as many rows by `source.id`.

**Position sent to Kevin:** don't add settled_at AND created_at — Ark only takes Completed rows, so define ONE `posted_date` (a DATE, bank value date). A settled_at sourced from our completion clock re-introduces the month-boundary bug (late-day settle, BAI2 processed next morning). Bank-true value date exists today ONLY for SVB wires; parity across rails = real work (thread BAI2/settlement date through OP + AchPush + non-SVB OW completion). Sharp point: for the posting-date field alone, Plaid is MORE authoritative than our API (reads bank posted date directly) — opposite of doc's Section-2 "API beats Plaid" thesis, which holds only for context fields (investor/purpose).

**posted_at vs settled_at (distinct; treasury tracks both but scattered/partial, never one clean per-txn field):**
- POSTED (inferred): `bai2_account_sync_file.file_date` — BAI2 file IS the daily bank statement, txn on file dated X → posted X. SVB-only.
- posted→settled inference lives ONLY in OW: `completed_at`=`file_date.prev_weekday` (`outgoing_wire.rb:493-501`) = inferred settled/value date from posted date; `bai2_previous_day_sync_file` matches across the two statements.
- SETTLED/effective real cols (ACH sub-flows only): `ach_pulls.treasury_prime_scheduled_settlement` (TP scheduled, AchPull+cross_transfers, NOT AchPush; used review_reason.rb:147); `dibs_ach_metadata.effective_date`/`dibs_intrafi_transactions.effective_date` (DIBS NACHA effective date). AchPush outbound effective entry date = `company_descriptive_date+1` (`outgoing_ach_file.rb:230`) but baked into NACHA batch header, NOT persisted on model. Also `crypto_settlement_reports.settlement_executed_timestamp` (crypto only).
- No uniform posted_at OR settled_at on any model. To satisfy Ark both dates: (a) persist effective/settlement date on AchPush + OP executions, (b) surface BAI2 posted date uniformly not SVB-only.

LedgerEntry has no settled/effective/posted col — only created_at/updated_at (checked schema). Eng Lead on doc = user f782843c-6af7-4803-b3fa-cca13a1c0d49; Katie = Product Lead 50025380.
