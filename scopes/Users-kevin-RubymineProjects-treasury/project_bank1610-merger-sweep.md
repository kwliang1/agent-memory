---
name: bank1610-merger-sweep
description: BANK-1610 — bank-only $129.70 sweep completing the missed 2023 merger of Lynwood Group Corp (CA 89173→89163); PR
metadata: 
  node_type: memory
  type: project
  originSessionId: 7412f370-2837-4492-a465-6eadca28eab7
---

**BANK-1610 shipped as PR #8192** (branch `kevinliang/bank-1610`, `Maintenance::BookTransferSubAccount443709To443710Task`). One-off bank-only TreasuryPrime `book` sweep of **$129.70** from SA **443709** (CA 89173, old/merged-away) → SA **443710** (CA 89163, current). Flipper/rollout: none — run once via `/maintenance_tasks` UI. **As of 2026-07-09 NOT yet executed** — awaiting Kevin's 👍 + live-TP-balance confirm.

Key facts (verified on prod read-only al console):
- `AccountMerge #498` (89173→89163, "Lynwood Group Corp", merged 2023-03-10). Merge's `merge_ledgers!` rewrote 89173's entries' revised_origin/destination → 89163, so **89163 revised balance already = $7,923.15** (audit still splits: 89173=$129.70, 89163=$7,793.45). Bank (balance-check SA 443710, 2026-07-09): external $7,793.45 vs treasury $7,923.15 → short exactly $129.70.
- **Mechanism = bank-only, NOT funds_migration.** Because the revised ledger already credits 89163, a ledgered transfer double-counts. Mirrors PR #8189 `BookTransferSubAccount271181To393235Task` (raw TP `book` API, no LedgerEntry/BookTransfer). Contradicted the spawn's "should move both sides" guess.
- Source located via **completed BookTransfer #454736** (2024-12-26): $129.70 moved inactive SA 318241 → active 443709, no egress since. Same-day BT #454737 consolidated 89163's own old SA into 443710 — Dec-2024 cleanup did each CA's *intra*-consolidation but skipped the *cross-account* merger sweep = "missed during merger". No real-money Transfer/CrossTransfer ever existed between the two CAs.
- `Accounts::BalanceService.cash_balance!` defaults to the **revised** ledger; balance checks' treasury side = `SubAccounts::BalanceService.full_internal_balance` → revised. `use_audit_ledger: true` gives the original/immutable view.

Guards added beyond the #8189 precedent (both real review catches): **ownership** (`assert_belongs_to!` verifies SA↔expected CA — untraceable misroute risk since no Treasury record written) and **prior-succeeded-`MaintenanceTasks::Run` no-op idempotency** (UI path only; `run_synchronously!` uncovered, documented). `MaintenanceTasks::Run` has `enum :status` incl `:succeeded` (auto-scope); Run `task_name` validated against real task classes (use e.g. `Maintenance::DemoTask` in specs, not a made-up name).

Gate: 6 rounds (heavy iteration) → passed. Specs 20/0 `--order rand`, Sorbet clean. Related: [[balance-check-destination-credit-fix]], [[bank1592-self-transfer-fix]].

Worktree gotcha this session: `make spec` with **no FILES runs the whole suite** and OOM-killed shared `treasury-mysql-1` (exit 137), taking it down for sibling worktrees — restart with `docker start treasury-mysql-1`. Run one spec via `docker compose ... run --rm --no-deps -e RAILS_ENV=test app bundle exec rspec <file>` (NOT `--no-deps`-less, which spins conflicting worktree-local db containers on port 9000). The worktree app container also boot-loops (temporal worker crash), so the long-running `app` service dies — use one-off `run` for specs. See [[worktree-never-raw-docker-compose]].

Status (2026-10-14, unverified, carried from the index line): not executed; awaiting Kevin's live-balance confirm.
