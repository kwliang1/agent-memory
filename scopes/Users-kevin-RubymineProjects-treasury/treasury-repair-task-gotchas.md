---
name: treasury-repair-task-gotchas
description: "Recurring traps when writing a Maintenance repair task that destroys prod ledger rows: dry_run proves nothing about writes, force_destroy! doesn't cascade, complete! forwards funds and stamps now."
metadata:
  type: project
---

Learned building the two repair tasks in treasury PR #8751 (Sept 2026). These bit in order and will bite again.

**`dry_run` passing is NOT evidence the run will succeed.** It stops after `verify_preconditions!` and never builds or destroys anything. Two real failures got past a green prod dry_run and were caught only by specs, which actually execute:
- Destroying a completed `Transfer` raises `DestroyNotAllowedError: PaymentMetric should not be destroyed`.
- A ledger entry created without `force_reason` runs the full validation path that dry_run never exercises.

**`EngBot::Indestructible.force_destroy!` marks only the instance it is handed.** So the object graph fails two ways, neither visible to dry_run:
- `dependent: :destroy` associates load fresh without the flag → `Permanent#prevent_destroy` **raises** mid-run. `Transfer has_one :payment_metric, dependent: :destroy` is the one that bites.
- Optional `belongs_to` referrers are never visited at all → they **silently dangle**. Guard explicitly: `BalanceCheck::Record#resolution_transfer` (UNIQUE index), `BookTransfer`/`QueuedTransfer`/`CrossTransfer#transfer_metadata`, and polymorphic `Transfers::Metadata#requester`.

**`Transfers::V2::StateService.complete!` does more than write a ledger entry.** It calls `forward_funds_to_active_sub_account_if_needed!` (`state_service.rb:356`): if `destination.active_sub_account != metadata.to_sub_account` it creates a **real bank transfer** moving the full amount out of the pinned sub. Always assert both accounts' `active_sub_account` against the pinned constants first. It also stamps the new LE `Time.current` — backdate it afterward (`created_at` is not in `LedgerEntry::READONLY_ATTRS`), because `SubAccounts::BalanceService#balances_for_sub_account` sorts on id alone and `Accounts::BalanceService` on `(created_at, id)`.

**`Transfer#create_ledger_entry!` silently returns the existing entry** if `metadata.ledger_entry` is present — no error. Assert it's nil, or the repair retires a credit and never replaces it.

**Restoring skipped callbacks:** use the macro (`LedgerEntry.after_create(:x)`, `IncomingWire.after_commit(:x)`), never bare `set_callback` — `after_create` injects `prepend: true` plus a conditional that a bare restore silently drops. `IncomingWire`'s `after_commit :update_flowdash_incoming_wire_task` has no `on:` filter, so it fires on **destroy** and must be suppressed around the whole transaction (it runs post-commit).

**PaperTrail is on** via `ApplicationRecord` → `Concerns::ApplicationWide::Tracked` (in `lib/`, not `app/models` — easy to miss when grepping). Destroys are versioned into `ModelVersion` with full attributes, so never dump row attributes into logs for "preservation". Disabled in test, so that path is unspeccable.

See [[mmf-frec-deposit-account-routing-collision]], [[feedback-serialize-mutation-agents]].
