---
name: bank1623-dup-booktransfer
description: "BANK-1623 — bank-only reversal of a duplicated $2,950.05 BookTransfer on CA 396654; PR"
metadata: 
  node_type: memory
  type: project
  originSessionId: e5bb4d34-efb8-4dfb-b192-261f2fea850f
---

**BANK-1623** (Balance Mismatch Purge project / Nova Foundations). Branch `kevinliang/bank-1623`, **PR #8212** (`Maintenance::BookTransferSubAccount166754To458194Task`). Built + green + reviewed 2026-07-12; awaiting Kevin's live-balance confirm + run via `/maintenance_tasks`. NOT yet executed.

**Root cause (prod read-only console):** On CA 396654 ("FBO Investors in Chaotica", active SA 458194, GHB Main) a $2,950.05 "Adjusting short amount for wire" book transfer settled once 2025-08-15 (**BookTransfer 662715**, ledger_entry 5045484 — final leg of the OutgoingWire 108696 chain: LE 5045482 CA396654→CA396655 → 5045483 →OW108696 → 5045484 →GlobalAccount 14). Re-issued 2025-08-19 (**BookTransfer 665119**, DIFFERENT idempotency token, same 458194→166754 295005c). The re-issue's ledger chain rolled back — **ledger_entry 5050006 never committed (gap: LE ids 5050004/5/6 absent)** — but its TP `book` call already fired. So ledger recorded it ONCE, bank did it TWICE. Net: SA 458194 (client FBO cash) short $2,950.05; GlobalAccount 14's SA 166754 (INTERNATIONAL_OUTGOING_WIRE_SETTLEMENT omnibus) long it. Note LE **5045482** (Kevin's "5045482") = the CHAIN HEAD, not either BT's LE — off-by-two from 5045484.

**Mechanism = bank-only, NO ledger** (Kevin confirmed "ledger correct, just duplicated the money movement"). Raw TP `book` 295005c from 166754 → 458194, writing NO LedgerEntry and NO BookTransfer (a ledger entry would CREATE an imbalance). Copied the dusk #8189 / sage #8192 pattern: `TreasuryPrime::ApiService.post(endpoint: Endpoint::Book.serialize, body: {amount, from_account_id: sa.treasury_prime_external_account_id, to_account_id, description}, idempotency_token:)`.

**Guards (5-round review gate hardened these):** `dry_run` string attr default 'true' (execute only on explicit 'false'; `dry_run?` = `.to_s != 'false'`); `already_executed?` = prior succeeded Run with `arguments.to_h['dry_run'].to_s == 'false'` (exact complement of `dry_run?`; blocks re-run iff prior run actually moved money — Cursor bot caught the original `!= 'true'` as inconsistent: it would falsely block after a nil/blank-arg dry run; fixed cc5987a); **`run_synchronously!` overridden to raise** (base version writes no Run record → bypasses idempotency guard; R1 Critical catch); `assert_remediation_premise!` verifies (1) 662715+665119 still completed 458194→166754 295005c, (2) `original.ledger_entry.present?` + `duplicate.ledger_entry.nil?` (the load-bearing "ledger recorded once" invariant — R1/R2 catch; dangling FK → belongs_to returns nil not raise), (3) no completed reversing BT 166754→458194 after the duplicate; `assert_belongs_to!(sa, type, id)` generalized for GlobalAccount source + CustomerAccount dest; `assert_book_transferable!`; live `assert_sufficient_source_balance!`. 31 specs, sorbet clean, R4+R5 fully clean (2-successive-clean gate).

**Residuals (documented, inherent to no-records reversal):** >24h re-run after TP token expires; prior RAW external reversal leaves no BookTransfer so premise check #3 can't see it (operator must eyeball TP history); concurrent runs before either `succeeded`. All backstopped only by TP idempotency-token dedup.

**Prevention follow-up (on the issue, out of scope):** two different idempotency tokens + identical params = idempotency can't catch a re-issued manual adjustment. Dedup guard on (from, to, amount, description) within a window, or hardened manual-adjustment tooling.

**Env gotchas this session:** write console (`-w`) Forbidden — "no access to GlobalConsoleWriters"; READ console (default, no flag) worked all session (contrast [[al-console-treasury-rbac]] which said read was flaky — it was fine 2026-07-12). Worktree husky hooks broken (missing `.husky/_/husky.sh`) → commit + push need `--no-verify`. Pre-commit claude-docs-check hook blocks amend until you assert docs audited. Specs: one-off `docker compose -f docker-compose.yml -f docker-compose.worktree.yml run --rm --no-deps -e RAILS_ENV=test -e MOCK_ENTITY_API= --entrypoint "" app bash -lc 'bundle exec rspec <file>'` (test DB `treasury_test_worktree`). Related: [[bank1604-book-transfer-reversal]], [[bank1610-merger-sweep]].

Status (2026-10-14, unverified, carried from the index line): not executed; awaiting Kevin's live-balance confirm.
