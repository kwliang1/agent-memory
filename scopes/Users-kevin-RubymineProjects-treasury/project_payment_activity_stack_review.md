---
name: project_payment_activity_stack_review
description: PaymentActivity stack (PRs #9001/#9002) reviewed 2026-09-30 — request_changes, 12 open findings, nothing posted to the PRs
metadata:
  type: project
---

Cameron's (`ctotheameron`) PaymentActivity stack: #9001 `payment-activity/01-model`, #9002
`payment-activity/02-lifecycle`. Backs the "Simplified Treasury Ledger API" Notion doc
(`7f461e86-6662-825d-a7dd-810bd2921d2f`). Reviewed 2026-09-30 over 5 adversarial rounds.
Verdict **request_changes**. Nothing posted to either PR — Kevin said inline-only, and the
human-reviewer gate applies anyway.

**Leads:**
1. `CustomerAccounts::MergeService` enumerates every account-scoped table by hand;
   `payment_activities` isn't in it, and `attr_readonly :customer_account_id` blocks the repoint.
   `merge_ledgers!:222` zeroes `revised_amount` — exactly `shown_in_ledger?`'s exclusion.
2. Every completed AchPull writes two activity rows (124,551 completed pulls). Root cause: the
   activity binds to the first entry touching a CustomerAccount — provisioning for money-out
   (`settled_at` too early), completion for money-in (splits). One line, opposite failure per
   direction of flow.
3. `transfer.rb:627` (`transfer_metadata: metadata`, added only to make the new hook work)
   inverts `attached_to_existing_ledger_entry?`. A regression the stack *introduces*.

**Shape guidance — the retraction matters more than the advice.** "Ask the eligibility predicate
once, derived from `shown_in_ledger?`" is WRONG and was retracted: implemented literally it
reproduces lead 3, because create-time and settle-time genuinely know different things. Correct
form: one owner for the question, two named methods for the two times it's asked. Move the hooks
to `after_commit` *before* reworking eligibility.

Also open: no backfill task (against `AGENTS.md`); two specs green for reasons other than the ones
they name (`state_service_spec.rb:124`, `create_service_spec.rb:73`); `settle!` bare `update` with
its boolean discarded; no index on `initiating_payment`.

Unsized and needed before acting on lead 1: **entries-repointed-per-merge × merge rate, on prod.**
Dev-snapshot numbers churned badly during review (one headline went 371 → 1, another 7,876 → 2) —
don't quote a volume from this review without re-deriving it.

Separate, PRE-EXISTING, not this stack's fault: `between_different_accounts`
(`ledger_entry.rb:496`) reads **in-memory** association state, so identical column values validate
or reject depending on object-graph assembly order. `TreasuryPrime::Transfers::StateService:138`'s
assign-inverse-then-save trips it. Surfaced to Kevin; filing is his call, not filed.

See also [[treasury-stale-shared-checkout]], [[feedback_backfill-with-ledger-changes]],
[[zsh-eats-colon-a-in-git-show-base-path]] (hit it again this session).

## Re-verified 2026-09-30 against 9002 `78df7e3` / 9001 `2345fa0` (Cameron force-pushed after the review)

Mechanism was rewritten into `payment_activities/{create,state,info}_service.rb`. Per lead:

- **Lead 3 (polarity) is FIXED.** Predicate now owned by `info_service.rb:130`, consistent at
  `:45` and `:140`. `transfer.rb:627` only adds `transfer_metadata: metadata`.
- **Lead 1 is STILL LIVE** — and the earlier framing was **wrong**: `attr_readonly
  :customer_account_id` (`payment_activity.rb:76`) does NOT block the repoint, because every
  `merge_service.rb` helper uses `update_all`, which bypasses readonly. Fix is one `update_all`
  beside `merge_service.rb:184`. That same `update_all` also means the new wire hook at
  `incoming_wire.rb:247` never fires during a merge.
- **Lead 2's shape advice was not taken** — hooks still `after_create` (`ledger_entry.rb:181`),
  and the two-row path is now explicit at `state_service.rb:100-107`.

Three cursor[bot] findings landed 2026-09-30, all confirmed by code read, all one root cause:
`mark_revised!` (`state_service.rb:50-56`) revises every row sharing `ledger_entry_id`, and
`create_or_find_by!`'s block runs only on create. Strongest of the three (stronger than cursor
stated): `hold!` (`incoming_wires/state_service.rb:192-221`) requires destination == customer
account and revises to the holding account; `release_hold_internal!:466` revises it back — so
**every** hold/release cycle permanently stamps the customer's settled row `revised_at`, and the
holding account retains a live settled row. Fix direction: scope `mark_revised!` /
`move_to_account!` by account, not by entry.
