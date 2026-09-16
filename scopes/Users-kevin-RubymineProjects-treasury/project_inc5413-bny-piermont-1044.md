---
name: inc5413-bny-piermont-1044
description: "INC-5413 $10.44 BNY→Piermont: NOT returned; auto-swept by BalanceChecks::ResolutionService because BNY isn't in EXCLUDED_PROGRAMS"
metadata:
  node_type: memory
  type: project
  originSessionId: 3e1aa6a0-7396-4d97-a67d-09bd609f7d01
  modified: 2026-08-31T22:35:00.945Z
---

INC-5413 / Linear I-2729 (opened 2026-08-04, still In Progress as of 2026-08-31). Investigated read-only via Metabase → Snowflake `STAGING_TREASURY` (db id 234; treasury prod replica, ~minutes fresh).

**Verdict: NOT returned.** $10.44 still at Piermont.

Chain: `Transfer` 191040 (idempotency `bcr:224108` → `BalanceCheck::Record` 224108) → `LedgerEntry` 5730975 (FUNDS_MIGRATION) → `DIBS::PaymentTransfer` 58075 → `DIBS::SubEntry` 365155. Created 2026-07-07T23:26:49Z, settled 2026-07-08T10:31:52Z.

Accounts (both **CustomerAccount 411006 "Rollups Reserve Account"** — a self-transfer):
- BNY: `SubAccount` 501802 / `DIBS::InternalAccount` 149 (BNY FBO id 8)
- Piermont: `SubAccount` 490735 / `DIBS::InternalAccount` 12301 (Piermont FBO id 3)

**Root cause:** SA 501802 was created with `closed_at == opened_at` (born inactive), and `'BNY Mellon'` (`PartnerBank::Program::DIBS_BNY_NAME`) is **not** in `EXCLUDED_PROGRAMS` at `app/services/balance_checks/resolution_service.rb:7-18`. `attempt_resolution!` scans `sub_accounts.inactive.not_terminated` (line 32) and auto-migrates anything under the $500k threshold with no human review. **This refires the moment BNY SA 501802 goes positive again** — it already clawed back a deliberate finance seed (`Transfer` 190271 / PT 57903, "per finance", $5 Piermont→BNY, seven hours earlier).

Composition: $5.44 real BNY residual (per sub-entry 319064 true-up "$39.27 DIBS vs $5.44 BNY") + $5.00 finance seed.

**Trap:** `LedgerEntry` 5747298 (2026-07-15, $5.44, GlobalAccount 100 → CA 411006) says *"Ledger correction: $5.44 at BNY sub never credited"* but posts `to_sub_account_id = 490735` (**Piermont**). Ledger-only — do NOT read it as a return.

Incident text says "the BNY Mellon account is not Rollups"; treasury data names it Rollups Reserve Account. Reconciliation (inference): IA 149's funding is entirely AngelList house cash (wire from Aryeh Friedman, ACH "from AngelList", 2× wires from AL ADVISORS MANAGEMENT INC., BNY penny tests) — a Rollups-*named* BNY C2 test account.

Fix options: add `DIBS_BNY_NAME` to `EXCLUDED_PROGRAMS`; or set `terminated_at` on SA 501802; or fix whatever mints a SubAccount with `closed_at == opened_at`.

Related: [[project_balance-check-resolution-followup]], [[project_bc-resolution-56174-462253]], [[project_bank1634-bny-cert-rotation]].
