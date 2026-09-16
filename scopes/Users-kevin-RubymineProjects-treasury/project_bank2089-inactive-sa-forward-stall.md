---
name: bank2089-inactive-sa-forward-stall
description: "BANK-2089 SHIPPED PR #8876: auto-heal guard now fundability-based (executed? || amount <= available_balance); queued phantom no longer disables the sweep; repair of T252581/T248904 still outstanding"
metadata: 
  node_type: memory
  type: project
  originSessionId: c67a5b3d-00b1-4116-beed-4623b62190d4
  modified: 2026-09-15T17:07:46.826Z
---

**SHIPPED as PR #8876** (branch `kevinliang/bank-2089`, commit c34c2fe64 signed, off origin/main, 2026-09-15). Linear BANK-2089 rewritten + retitled "Stale funds-migration forwards stall forever and disable the inactive sub-account auto-heal sweep", Triage→Todo, Medium→High, S→M.

**The sweep** = `BalanceChecks::ResolutionService.attempt_resolution!`, called inline from `balance_checks/check_service.rb:142` (Flipper `balance_check_auto_heal_inactive_subaccounts`, ON) inside the `ledger-balance-check` cron (`5 */8 * * *`). Migration transfers carry idempotency `bcr:<balance_check_record.id>` — **minted fresh per run, so it dedups nothing across runs**; the BCR sits on the **active** SA (attempt_resolution! returns early unless `sub_account.active?`), so querying BCRs by the inactive SA id finds nothing.

**Root cause:** `ach_pulls/state_service.rb:170-185` forwards on sub-account identity alone, never on whether the money is still there. Pull sits `provisioned` 3–6 days; sweep runs every 8h; sweep wins. **The damage wasn't the stalled transfer** — it was that `pending_migration_exists?` counted `queued` as pending (`Transfer.pending` = non-terminal, `transfer.rb:207`), permanently disabling auto-heal for that CA.

**As shipped** (`resolution_service.rb:144-150`, renamed `blocking_migration_exists?`, now takes `available_balance`):
```ruby
.any? { |transfer| transfer.executed? || transfer.amount <= available_balance }
```
`executed?` = `!created? && !queued?` (`transfer.rb:605`) — covers the `created` variant too. Self-stabilizing: the sweep sizes each transfer to exactly `available_balance`, so next run its own transfer satisfies `<=` and blocks. **The `<=` is load-bearing — never tighten to `<`.**

**Rejected in review (my first attempt was wrong):** a blanket `.not_queued` scope. `customer_accounts/balance_service.rb:244-245` (`from_elsewhere`, summed into the debit total, no self-transfer carve-out unlike `from_active_self`) means every extra pending migration widens the very balance-check difference that spawns the next run — self-sustaining 8-hourly mint. Verified, not hypothetical.

**Monitor gotcha worth remembering:** never build a Datadog monitor on `payment.health.*` concern gauges filtered by `lifecycle_segment` — `emit_zero_baselines` (`monitor_activity.rb:138-149`) omits that tag, so the series vanishes on recovery and the monitor fires once and never clears. Shipped instead: unconditional `transfer.queued.count` / `.max_age_minutes` via the shared `emit_queued_gauges(relation, metric_prefix)` (deduped with `emit_queued_op_gauges`), emitted at the **top** of `execute` so a downstream raise can't suppress it (makes `notify_no_data` real). Monitor `ops/datadog/monitors/transfer-stuck-in-queued.json`, critical 7200 min, no warning.

**OUTSTANDING REPAIR (blocks merge — monitor is red until done):**
- **T252581** $10k CA 469607 — confirmed phantom, safe to cancel.
- **T248904** $23k CA 469680 — **do NOT cancel**; $23k unaccounted (ledger says held, active SA516732 reports $0 at Increase, no sweep ever ran). Read TP balance for SA516551 first. T248905 ($23k customer investment) queued behind it.
The sweep will NOT clear either — it returns early on zero balance (`resolution_service.rb:65`).

**Known residuals** (in a Linear comment on BANK-2089): a migration stuck in `submitted`/`processing` whose money never left still blocks forever; the guard matches on `from_sub_account_id` so chained legs are invisible (mirror chain unreachable by construction — returns early on self-transfer; cross-TP reachable only GHB-main ↔ GHB-manco).

Related: [[bc-469607-ach-pull-phantom]] (same CA + AchPull 571386), [[review-gate-caught-own-goal-bank2089]]
