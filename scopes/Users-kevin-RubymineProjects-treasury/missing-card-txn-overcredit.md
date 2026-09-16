---
name: missing-card-txn-overcredit
description: "Balance-check overcredit class — TP settles debit-card withdrawals that never post to Treasury's ledger, so internal > bank on management-company card accounts"
metadata:
  node_type: memory
  type: project
  originSessionId: ecd41d23-9054-488a-8ad3-2c50b2ded378
  modified: 2026-07-23T19:36:56.880Z
---

Confirmed 2026-07-23 (comet session) on CA **346735** (management company, 2 cards, active sub 420071, TP acct_11k6pp622g08s1c, tp_instance 2 management_company).

**Failure mode:** debit-card withdrawals settle at Treasury Prime (balance drops) but never get a `TreasuryPrime::CardTransaction` + WITHDRAWAL ledger entry on Treasury → internal never debits → **internal cash_balance > bank available_balance** (over-credit). Direction discriminates it from [[duplicate-wire-debit-mismatch]] (also internal>bank but wire-side) and from the incoming-wire phantom in [[unprocessed-ach-return-overcredit]].

**Concrete case:** internal $49,406.39 vs TP $37,904.68 (gap $11,501.71 live; balance-check 2026-07-23 15:11 UTC recorded internal $49,469.97 vs bank $38,639.87 = **+$10,830.10**). `Oncall::TreasuryPrime::CardTransactions::ResolutionService.find_missing_card_transactions(ca)` found **136 TP card withdrawals / $13,964.22** with no CardTransaction record. Split: **98 / $10,885.27 genuinely un-debited** (no matching LE — the real over-credit, ties to the $10,830 gap within noise) + **38 / $3,078.95 WARNING** (a matching-amount LE already exists → link-only fix, NOT a new debit). Missing txns span 2025-05-12→2026-07-04, 120 of 136 on newer card card_11mcvfxz6dtf1ds. So card→ledger sync has dropped settled withdrawals on this account for >1yr.

**Fix (WRITE, needs Kevin's OK — not done):** per genuinely-missing txn `ResolutionService.create_required_card_transaction_records!(card_id, ttx_id)` (creates CardTransaction + WITHDRAWAL LE); per WARNING txn `create_required_card_transaction_records!(card_id, ttx_id, create_ledger_entry: false, existing_ledger_entry: le)` AFTER manually verifying the LE corresponds. Amount-only matching is UNSAFE (repeated $140 DELTA / small amounts collide) — never batch-blind-create or the 38 double-debit. Residual ~$616 = real-time spend between API calls + noisy amount-matching; not penny-perfect until per-txn matched by hand.

**Service:** `app/services/oncall/treasury_prime/card_transactions/resolution_service.rb` — self-described "temporary service to help with management company balance mismatches due to missing card transactions." Requires `ca.management_company_account?`. Fetches `account/<tp_external_account_id>/transaction` (needs TP API → WRITE console) filtered to `type==withdrawal && type_source==card`; missing = no `CardTransaction.exists?(treasury_prime_external_transaction_id:)`. Method repeatable via [[treasury-prod-console-access]].

**Systemic gap:** no reliable automated card-sync; only this manual oncall tool exists. Sibling management-company card accounts likely have the same drift — worth a sweep (management_company accounts, compare TP card withdrawals vs CardTransaction records).
