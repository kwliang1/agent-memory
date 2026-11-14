---
name: feedback-no-update-all-keep-paper-trail
description: Never write model rows with update_all/update_columns/update_column in app or maintenance-task code; they skip PaperTrail. Use with_lock + update!.
metadata:
  node_type: memory
  type: feedback
  originSessionId: fc085396-ec55-4d00-a037-c1abfafcac60
  modified: 2026-11-05T17:23:06.822Z
---

Don't use `update_all`, `update_columns`, `update_column` or `insert_all`/`upsert_all` to change rows of a tracked model, including in maintenance-task backfills. Kevin: "papertrail is important" (2026-11-05, on the #9449 pending_activation backfill).

**Why:** in treasury every model gets `has_paper_trail` via `Concerns::ApplicationWide::Tracked` (lib/concerns/application_wide/tracked.rb). `update_all` writes no `ModelVersion`, skips validations (e.g. #9485's one-deferred-request-per-account check) and callbacks. The audit trail is what ops and compliance use to explain a change.

**How to apply:** per row, `record.with_lock { next if !still_eligible; record.update!(...) }`. That's safe under live writes, records the version, and raises on an invariant break. A data repair may bypass `transition_to!` (no legal transition needed) but not PaperTrail. If a bulk write is genuinely required, ask Kevin first. Flag `update_all` on tracked models in reviews. Related: [[feedback-repair-data-not-invariants]], [[feedback-backfill-with-ledger-changes]].
