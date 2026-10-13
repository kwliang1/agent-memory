---
name: ach-pull-cross-ca-sub-landing
description: "ACH pull whose sub_account belongs to a DIFFERENT CustomerAccount than its customer_account — ledger and bank diverge, revision can't fix it, needs a cash-only USER_OVERRIDE transfer"
metadata:
  node_type: memory
  type: project
---

**Case: AchPull 576121, $3,000, 2026-09-29 (Erik Andreassen, Piermont/DIBS program 17).**
`ach_pull.customer_account_id = 473396` but `ach_pull.sub_account_id = 518842`, and 518842 belongs to
CA **473397** — a duplicate person CA (different `owner_entity_api_id`) deactivated 09-24. Result:

- `ach_pulls/state_service.rb:151` writes the completion LE to `ach_pull.customer_account` → credited
  CA473396 / sub 518978.
- `DIBS::Client.submit_ach!` pulled into `ach_pull.sub_account.dibs_internal_account_id` → cash landed
  in **518842**.
- Ledger said 518978, bank said 518842. Both subs flagged by balance check every 8h.
- Downstream: the investment transfer T266015 sat `queued` for 4 days — `check_if_insufficient_payment_processor_balance` reads `initiating_sub_account.dibs_balance` and 518978 was $0.

**Why the auto-forward didn't fire:** `ach_pulls/state_service.rb:172-174` forwards only when
`active_sub_account.partner_bank_program != ach_pull.sub_account.partner_bank_program`. Both subs were
program 17, so the guard was false. Its own comment says "if the ACH landed in an inactive sub account"
— the guard tests the bank program, not sub-account identity. Same family as [[bank2089-inactive-sa-forward-stall]].

**RevisionService cannot fix this.** `revise_ledger_entry_destination!` derives `from_sub` from the LE's
*current* destination and validates membership (`revision_service.rb:218-221`). LE destination was
CA473396, whose only sub (518978) held $0 at the bank — so any revision tries to move money out of an
empty account and stalls. This is the error to expect when ops says "revision isn't working".

**What works — a cash-only transfer, verified by rolled-back dry run:**
```ruby
Transfer::Request.new(
  origin: CA_owning_the_landing_sub, destination: CA_on_the_ledger,
  from_sub_account: landing_sub, to_sub_account: ledger_sub,
  amount: ..., category: LedgerEntry::FUNDS_MIGRATION,
  revised_ledger_entry: original_le,   # optional: makes it RENDER as a revision
  ledger_entry: original_le,           # REQUIRED: suppresses a new LE
  force_reason: LedgerEntry::USER_OVERRIDE, force_note: '...', forced_by_user: user,
)
```
Load-bearing details, all confirmed in prod:
- `Transfer#sub_accounts_compatibility` (`transfer.rb:838-851`) is **unconditional** — no force_reason
  escape. `from_sub` MUST belong to `origin`, so origin has to be the CA that owns the landing sub.
- `ledger_entry:` makes `create_ledger_entry!` (`transfer.rb:617-620`) reuse the existing LE → **0 new
  entries**. Without it a second LE is written and the SUB-level ledger goes to −$3,000 / +$6,000
  (CA-level `balance` did not move in-transaction; unverified whether that's a rollback artifact).
- `validate_ledger_entry_existence_on_create` (`transfer.rb:949`) only allows `ledger_entry:` for
  ACCOUNT_MERGE or **USER_OVERRIDE** — that's why the override is needed, not optional.
- Category must be **FUNDS_MIGRATION**: `sufficient_balance` (`transfer.rb:788-789`) returns early when
  force_reason+force_note are set, but only on the funds-migration branch. `DESTINATION_CHANGE` falls
  through to `origin.available_balance >= amount` (`transfer.rb:813`) and fails on a $0 origin.
- `funds_migration_transfer?` also makes `forward_funds_to_active_sub_account_if_needed!`
  (`state_service.rb:355`) skip, so it won't bounce back.
- Routes as **Book** (same partner bank + processor, not BNY) and does not queue — fundability reads
  the *from* sub's `dibs_balance`.

**Dry-run recipe:** wrap `Transfers::V2::CreateService.send(:create_transfer!, req)` +
`QueueingService.queueing_reasons(t, check_payment_processor_balance: true)` +
`t.create_ledger_entry!` in `ActiveRecord::Base.transaction { ... raise ActiveRecord::Rollback }`.
Safe: the only side effects are outbox rows (`BackgroundOutboxActivityDispatcher` → `perform_later`)
and they roll back; the DIBS HTTP call happens later in `submit!`. Skip `execute_transfer!`.
**Do not define a top-level `def try` in a rails-runner script** — it shadows ActiveSupport's
`Object#try` and blows up deep inside ActiveRecord.

Related: [[funds-migration-autoforward-stranding]], [[treasury-prod-console-access]],
[[treasury-console-pod-stdin-eof-workaround]].
