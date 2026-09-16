---
name: funds-migration-autoforward-stranding
description: Treasury balance-mismatch failure mode — auto-forwarder strands a deposit on the active sub-account after a bank migration; reverse it with a funds_migration maintenance task
metadata: 
  node_type: memory
  type: project
  originSessionId: dc4cfc37-59d9-4393-bf6d-6ee6c55baf5d
---

Recurring treasury balance-check failure mode (seen 2026-07-09, CA 454945): an LP overdraws bank A (e.g. GHB), is migrated to bank B (e.g. DIBS/Piermont), then deposits money to clear the overdraft — but the deposit lands on the now-*inactive* bank-A sub-account, and `Transfers::V2::StateService#forward_funds_to_active_sub_account_if_needed!` auto-forwards it to the active bank-B sub-account. Result: +$X on active B, −$X on inactive A, CA ledger already nets $0. It surfaces as `BalanceCheck::Record`s on the active sub-account.

Fix = a one-off maintenance task creating a `FUNDS_MIGRATION` transfer B→A (active→inactive) to reverse it. Key verified facts:
- `FUNDS_MIGRATION` is direction-agnostic: origin == destination == CA, differs only in from/to sub_account; balance-neutral for the CA (completion LE credits+debits same account). force_reason `FUNDS_MIGRATION` lets origin==destination LE pass validation ([[treasury-schema-load-landmine]] repo).
- Cross-bank/processor (e.g. DIBS→GHB) routes as an ACH; `DIBS::Transfers::V2::StateService#submit_ach!` works and `submit!` auto-registers the counterparty first. Off-ledger for days.
- The auto-forwarder will NOT bounce it back — `state_service.rb` short-circuits on `funds_migration_transfer?`.
- `BalanceChecks::ResolutionService` only auto-resolves POSITIVE stranded funds inactive→active, so this reverse/negative case needs a manual task.

**Why:** matches Kevin's [[feedback-backfill-with-ledger-changes]] and [[balance-check-gaps-discussion]] themes; likely to recur across LPs migrated between banks.

**How to apply:** query the CA in `al console` (read, prod) to confirm per-bank physical balances + ledger=$0 before writing; hardcode account ids with id-drift/inactive/terminated/source-balance guards; make it idempotent via stable idempotency_token + early existence check.
