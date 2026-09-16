---
name: balance-check-resolution-followup
description: Follow-up PR
metadata: 
  node_type: memory
  type: project
  originSessionId: 2550bd47-3ed3-45da-8f6e-f9cf91b74ecb
---

Follow-up to the balance-check-resolution stack (#7996-#7998): add a resolution transfers UI.

**What:** Add a `resolutionTransfers` computed GraphQL field on `BalanceCheckRecordType` that queries `Transfer.fund_migration_transfers.where(origin: customer_account)` filtered by time window around `checked_at`. Frontend renders an expandable row or enhanced tooltip showing: transfer ID, state, amount, from SA → to SA for all resolution transfers (not just the first one linked via FK).

**Why:** The current design stores only `resolution_transfer_id` (one FK) on the record, but multiple inactive SAs can each produce a migration transfer. This follow-up shows the full picture.

**How to apply:** Base on PR #7998 (`kevinliang/balance-check-resolution-graphql`). ~1.5 hrs estimated. Backend: computed field, no migration. Frontend: expandable row or mini-table in tooltip.

**Scope:** Kevin confirmed this should be a distinct PR, not part of #7998.
