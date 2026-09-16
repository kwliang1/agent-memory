---
name: treasury-spec-tasks-maintenance-flake
description: "spec/tasks/maintenance/create_*_missing_card_transactions_task_spec.rb assert UNSCOPED global LedgerEntry counts — adding any file to spec/tasks reshuffles order and surfaces them; don't misattribute to your diff"
metadata: 
  node_type: memory
  type: reference
  originSessionId: f47c16b3-3921-4f56-973d-9f74cd90f794
  modified: 2026-07-29T06:35:57.847Z
---

Treasury's `spec/tasks/maintenance/` family is order-dependent and fails on its own. Verified 2026-07-28: `rspec spec/tasks/maintenance/` **alone** gave 0 / 1 / 1 failures across seeds 26366 / 3586 / 29294, and 4 / 1 / 0 failures across three runs of the *same* seed 3703.

**Mechanism:** all 11 `spec/tasks/maintenance/create_*_missing_card_transactions_task_spec.rb` assert on **unscoped global** counts — e.g. `not_to change { LedgerEntry.count }`, `expect(LedgerEntry.where(category: LedgerEntry::WITHDRAWAL).count).to eq(0)` — none scoped to the account under test, each keyed to a hard-coded production `CUSTOMER_ACCOUNT_ID` (272_376, 345_610, …). Any `LedgerEntry` leaked by an earlier example group flips them. `tp_outgoing_wire_imad_backfill_job_spec.rb` is in the same family. A second, independent failure mode in the shared-MySQL worktree setup is `ActiveRecord::Deadlocked` / `Trilogy::ProtocolError: 1213` when sibling worktree containers run specs concurrently.

**The trap I nearly fell into:** adding *any* new file to `spec/tasks/` reshuffles group order and surfaces more of the latent set. I compared "clean main = 0 failures" against "my branch = 4 failures" on the same seed and same file set, and concluded I'd caused a regression. I hadn't — re-running the *same* seed three times gave 4, 1, 0. **A deterministic code bug cannot produce a varying failure count/set on a fixed seed; that variance is the tell.** Always repeat the same seed several times before attributing.

Disambiguation: `intrafi_spec.rb`'s `:with_balance` factory trait creates `DIBS::SubEntry` rows (DIBS's own ledger) via `DIBS::SubEntries::CreateService`, never `LedgerEntry` rows — so it mechanically cannot move the counters those specs assert on.

**How to apply:** if a `spec/tasks` shard goes red, check whether the failures are `create_*_missing_card_transactions_task_spec.rb` / `tp_outgoing_wire_imad_backfill_job_spec.rb`. If so it's this pre-existing flake — retry to confirm, don't chase it into your diff. Fixing it means scoping those 11 specs' assertions to the account under test; log it separately.

Related: [[rake-spec-double-load-tasks]], [[spec-neighborhood-must-include-tasks]], [[treasury-outgoing-transfers-resolver-flake]], [[treasury-worktree-dev-loop]].
