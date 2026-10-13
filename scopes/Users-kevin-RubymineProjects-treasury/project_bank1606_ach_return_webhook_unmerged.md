---
name: project_bank1606_ach_return_webhook_unmerged
description: "PR #8202 (BANK-1606) built the TP incoming-ACH/wire return webhook ingestion, reached clean+green, then was CLOSED UNMERGED for lack of a human approver — BANK-1606 is wrongly marked Done, so the gap is still live in prod"
metadata:
  node_type: memory
  type: project
---

**The fix for "TP returns an incoming ACH credit and Treasury never books it" already exists on a closed
PR. Do not rebuild it from scratch.**

- PR **[#8202](https://github.com/angellist/treasury/pull/8202)**, branch `kevinliang/bank-1606-auto-return-incoming-payments`, worktree `.worktrees/treasury-reef`. 7 files, +309.
- Subscribes TP `incoming_wire.update` + `incoming_ach.update` in `WebhookConfigService#configure_default_webhooks!`, routes them in `Api::TreasuryPrimesController`, and on `status == 'returned'` drives the **existing** `IncomingWireSyncService.return_incoming_wire!` → `IncomingWires::StateService.return!`. No new money-movement logic, only the trigger.
- **Closed unmerged 2026-07-27** by kwliang1. **There is no technical objection** on the PR or in the
  session thread (DM `D0BE3RB4Y00`, `thread_ts=1783641983.109279`, session `reef`, 33 replies — read in
  full). Last status was *"open, mergeable, but `blocked` — `review_decision` is null, just waiting on a
  human approving review."* Kevin's next message was `kill`, which ended the tmux session; the PR was
  closed the same day. **It starved for a reviewer, it wasn't rejected.**
- **BANK-1606 is marked Done (2026-07-24), three days BEFORE the PR was closed.** The issue reads as
  shipped when nothing landed. Same for the refs BANK-1596 / BANK-1598. Don't trust that Done.

**Why it's worth reviving rather than redoing.** It had already absorbed real review: 3 Cursor findings
(all valid, all fixed) — a lock-ordering race on the state gate, a `ttx_` vs `iw_` lookup gap affecting
**108** wire-type IncomingWires, and a created-wire resurrection race (fixed by auto-returning **only
`provisioned`**, since a `created` wire holds no balance). Devin clean, 4 agent rounds clean, rebased
onto main 7/20, Sorbet clean, 105 examples / 0 failures.

**The join key, verified twice, two months apart.** TP's `incoming_ach.original_transaction_id` ==
the `ttx_` we store in `IncomingWire.treasury_prime_wire_id`. July: `inach_11mtbjs58wp1d3d` →
`ttx_11mtbjs88wp1ee5` == IncomingWire 295427. 2026-09-29: the return txn's **`trace_id`** field carries
the same pointer (`ttx_11nbp16ebgsdxty`.trace_id == `ttx_11nbn610bgk0kkk` == IW 324088); `incoming_ach_id`
matches too. Either field works — no fragile amount-matching needed (which is what the *check*-return
path in `WebhookTransactionSyncService` is stuck with).

**Still parked from July, both required for the fix to actually do anything:**
1. Rollout — `TreasuryPrime::WebhookConfigService.configure_default_webhooks!(treasury_prime_instance:, webhook_url:)` **per instance** (main + management-company) in prod. Until that runs the merged code is dead: prod confirmed `incoming_wire.create: 133,978` vs `incoming_wire.update: 0`, `incoming_ach.*: 0`.
2. Backfill of the stuck tail. July exposure: 93 provisioned wires, 42 ACH-credit ≈ $3,005. Recommended shape was an ops-confirmed allowlist task, not an auto-sweep.

Related: [[unprocessed-ach-return-overcredit]] (the balance-check symptom), [[bank-1744-stuck-provisioned]]
if written, [[tp-nil-transaction-balance-filters]].
