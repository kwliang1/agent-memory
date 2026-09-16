---
name: maintenance-task-array-collection-gotcha
description: maintenance_tasks Array collections resume by positional offset → silent skips under a shrinking filter; use a Relation
metadata: 
  node_type: memory
  type: reference
  originSessionId: 63f3b02c-749a-472a-b632-20bae0656acc
  modified: 2026-07-24T22:56:27.748Z
---

For a `maintenance_tasks` task whose `process` mutates the same column the collection filters on (a **shrinking filter**, e.g. `where(transfer_id: nil)` while process sets `transfer_id`), the collection MUST be an `ActiveRecord::Relation`. The gem gives Relations a **keyset cursor** (`id > cursor`, re-runs the filtered relation per batch) which is resume-safe — rows leaving the filter behind the cursor are never skipped or re-yielded.

A `T::Array` collection is the trap: the gem resumes an Array by **positional offset** (`drop(cursor+1)`), so on any interrupt+resume (deploy SIGTERM, UI pause, job-iteration batch boundary) the shrunk array shifts left under the stale offset and it **silently skips unprocessed rows while reporting "completed."** The `/maintenance-task` SKILL's "shrinking-filter is safe" note is scoped to the keyset path only — it does NOT hold for Arrays.

To span two tables (no shared STI), don't union them into an Array — iterate a **parent Relation** instead. Real case (BANK-1698, [[bank1698-…]]): to migrate `MoneyMarketFund::Buy` + `Sell` off CrossTransfers, `collection` returns `CrossTransfer.where(id: <buy ct_ids>).or(CrossTransfer.where(id: <sell ct_ids>))` and `process(cross_transfer)` looks up the order — a keyset Relation over the CTs, resume-safe. Two independent review agents caught this; it would otherwise have shipped as a silent partial migration gating an irreversible column drop.
