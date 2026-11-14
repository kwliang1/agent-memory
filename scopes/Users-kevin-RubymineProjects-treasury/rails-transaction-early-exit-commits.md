---
name: rails-transaction-early-exit-commits
description: Treasury has committed on return/break inside transaction blocks since the 7.2 bump (2025-04-18); Rails 8 changes nothing, and the commit_transaction_on_non_local_return flag is a no-op
metadata:
  type: project
---

Treasury jumped from Rails 7.0.8.4 to 7.2 on 2025-04-18 (#4983) and skipped 7.1. 7.0 silently rolled back a transaction whose block exited via `return`/`break`/`throw` after a write (`abstract/transaction.rb:336`). 7.2.4 always commits unless an exception is raised (`abstract/transaction.rb:612-645`), and Rails 8 does the same. `config.active_record.commit_transaction_on_non_local_return` is a deprecated no-op on 7.2.4: its setter only warns (`active_record.rb:354`).

BANK-2403 (2026-10-23) was written on the opposite premise. The audit found 118 non-local exits across 367 blocks (app, lib, backend/dibs), and none relies on rollback: https://claude.ai/artifact/G4oYRkUBA1u7zV85MSx5U1. Kevin decided against converting them to `next` or adding a lint rule, because an early exit committing is documented behaviour and not a hazard.

**Why:** a future Rails-upgrade plan or reviewer may again claim that "Rails 8 flips transaction early-exit behaviour". It doesn't, for treasury.

**How to apply:** don't re-audit or re-propose the guardrail. Also note that `rubocop-angellist` pins `TargetRailsVersion: 7.0`, so rubocop-rails cops gated on Rails ≥ 7.2 still run here, until someone bumps that pin. The first audit pass missed `backend/dibs` entirely, so always scan `backend/` along with app/lib. Related: [[treasury-stale-shared-checkout]].
