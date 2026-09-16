---
name: bai2-458-rtp-debit
description: "BAI2 code 458 = RTP debit (return of an incoming RTP); the three gates a new BAI2 type code must clear in treasury, not just the constants file"
metadata: 
  node_type: memory
  type: project
  originSessionId: f523bd46-f46b-441f-a99c-4a3ab16700de
  modified: 2026-07-30T23:11:48.259Z
---

BAI2 detail code **458 = "Real Time Payment", DEBIT** (X9 BTRS RTP codes; credit counterpart 158 = `REAL_TIME_PAYMENTS`, summaries 159/459). In treasury these show up as the **outbound return of an incoming RTP**, matched to the original `IncomingWire` by `customer_reference`. Shipped 2026-07-30 as PR #8416 (`Bai2SyncFiles::WireProcessingService.process_returned_real_time_payments!`).

**Adding a BAI2 type code is never just `lib/bai2_constants.rb`** — there are three gates:
1. `CombinedTypeCodes::SUPPORTED_{CONCENTRATION,DISBURSEMENT}_TRANSACTIONS` — read by `validate_bai2_file!`. (The bare `TypeCodes::SUPPORTED_*` twins have **zero readers** — dead mirrors.)
2. `Bai2IncomingWireFile::EXPECTED_TRANSACTION_TYPES` — a second, narrower allowlist that raises `'Unexpected transactions in IncomingWireFile.'`
3. If the code moves money, something must **ledger** it or `GlobalLedger.confirm_balances_sum_to_fbo_balance!` fails. That check tolerates ONLY an exact match on the INC-5144 constant ($14,842.62), so any extra drift — even $0.02 — raises. It reads the **bare** `GlobalAccount.external_outgoing_funds` (global_ledger.rb:113); for SVB, bare and program-scoped both resolve to GlobalAccount#2.

Only add a code to the **disbursement** list if a disbursement handler exists — otherwise a debit is accepted that nothing ledgers, and drift that happens to equal the tolerance passes a broken ledger silently. Failing validation loudly is better.

**Don't match returns by amount.** Prod has ~70 unassigned `IncomingWire`s with `amount_cents=1` and a $0.01 balance. Use `customer_reference`: of 131,674 SVB wires with one, only 9 values repeat and all are placeholders (`"0"` x30341, `"Book Transfer"`, `"SWIFT Message"`, `"NOTPROVIDED"`, `"none"`) — **no 32-hex-UUID-shaped reference has ever collided**.

Ordering in `process_concentration_account_txns!` is load-bearing both ways: reference-matching must run **after** `process_incoming_wires!` (`validate_debit` rejects a debit on a wire with no credits) and **before** `process_reversed_incoming_wires!` (which claims unassigned wires by amount).

A blocked BAI2 file blocks the whole pipeline: `download_and_process_files!` calls `download!` *before* the `with_errors` gate, so unprocessed files pile up, and `lib/tasks/bai2.rake` raises bare `"Multiple unprocessed wire files"` once two exist — killing account_sync entirely. See [[incoming-wire-manual-return-gotchas]], [[treasury-worktree-dev-loop]].
