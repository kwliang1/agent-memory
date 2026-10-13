description: "BANK-2089 SHIPPED PR #8876: auto-heal guard now fundability-based; repair DONE (both cancelled) and my T248904 diagnosis was wrong — the wire was returned, not missing"---
name: bank2089-inactive-sa-forward-stall
description: "BANK-2089 SHIPPED PR #8876: auto-heal guard now fundability-based; repair DONE (both cancelled) and my T248904 diagnosis was wrong — the wire was returned, not missing"
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

**REPAIR — DONE, and my diagnosis was partly wrong.** Both cancelled (T248904 09-15, T252581 09-16). **T248904 was NOT "$23k unaccounted for"** — the incoming wire was RETURNED (LE5847855 DEPOSIT 09-04 / LE5862961 WITHDRAWAL 09-15, same ref INVE0FB433). An incoming wire landed at a closed SA, never forwarded, got returned to sender. I read "active SA $0 + ledger $23k" as money missing when "not yet returned" fit the same evidence. Lesson: label inference as inference — and the prod read console CANNOT read TP balances at all (`ArgumentError: Failed to open TCP connection`), so "read the bank first" was un-followable advice from my own tooling. STILL LIVE: T248905 ($23k Investment in Overlord Labs) queued and unfundable since its backing wire returned; CA469680 available_balance = -$23,000.

**Known residuals** (in a Linear comment on BANK-2089): a migration stuck in `submitted`/`processing` whose money never left still blocks forever; the guard matches on `from_sub_account_id` so chained legs are invisible (mirror chain unreachable by construction — returns early on self-transfer; cross-TP reachable only GHB-main ↔ GHB-manco).

Related: [[bc-469607-ach-pull-phantom]] (same CA + AchPull 571386), [[review-gate-caught-own-goal-bank2089]]

**2026-10-05 (verified on prod write console, read-only query; write console now works via push + `rails runner`):** T254942 cancelled (09-17), T255082 cancelled (09-18), T248905 completed (09-18). Zero queued FUNDS_MIGRATION transfers older than 2 days. No live orphans. #8876 still open; go/stop on cancel-orphans still undecided.

**2026-10-05 follow-up shipped to #8876 (`1966ec907`, pushed, not merged):** Kevin chose "include the follow-up here". Instead of cancel-orphans (draft discarded, snapshot in session scratchpad), the sweep now subtracts AchPulls in `AchPull::FUNDS_IN_FLIGHT_STATES` (submitted/processing/provisioned/pending_return) — prevents the orphan at the source. Read order is load-bearing: in-flight total → bank balance → blocking check (spec-pinned). Gate: 10 rounds, clean on 9+10. Scoped OUT: incoming wires (Provisioned → forward at `transfer!`) and transfer-completion forwards have the same race — follow-up pending Kevin. Pre-existing orphans can still be paid by QueueingService from a later pull — check queued forwards before deploy. Harsohail reply drafted, NOT posted (awaiting approval).

**2026-10-06:** Harsohail reply posted (Kevin-approved, issuecomment-6007863228). CI green 33/33 on `1966ec907`; awaiting Kevin's merge. Wire/transfer-completion follow-up filed as **BANK-2224** (Kevin, cycle Tamarind #57) — to be picked up by a separate session. Ticket is self-contained; base it on main after #8876 merges (reuses `in_flight_*` pattern + read-order spec).

**2026-10-08:** #8876 MERGED 17:39Z (approved by dcetlin). BANK-2089 done; BANK-2224 open for a separate session.
