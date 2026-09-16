---
name: transfer-229393-ivc-pull-balance-bypass
description: "Transfer 229393 ivc_pull pos2 \"insufficient funds\" deadlock — root cause + treasury PR #8586 fix"
metadata: 
  node_type: memory
  type: project
  originSessionId: 346ce300-0b4e-4f79-b2cc-db302ab4b989
  modified: 2026-08-18T20:46:39.214Z
---

Transfer 229393 (OutgoingPayment IvcCascade **pos2**, IVA #165673 → On-core #288464, $6,050 Book, force_reason `OUTGOING_PAYMENT_FUNDING`) deadlocked on `complete!` with "Origin has insufficient funds" — 21 failed TP webhook completions, could never self-resolve.

**Root cause:** `create_step!` (`outgoing_payment/plans/base.rb:52-55`) tags pos>1 steps `force_reason=OUTGOING_PAYMENT_FUNDING` to bypass the balance check, but `CustomerAccounts::ValidateBalanceService:9` only short-circuited for `CROSS_TRANSFER`/`TP_ACH_PULL_REVERSAL`. So completion (`create_ledger_entry!` → `ledger_entry.rb:477`) validated against `origin.available_balance`, which already subtracts the in-transit transfer as a pending debit (`CustomerAccount::BalanceComputation#pending_debit_amount`). When origin holds *exactly* the step amount → available nets to $0 → `$0 >= amount` false → fails forever. Key: `ledger_entry.rb:479` ALREADY full-trusts `OUTGOING_PAYMENT_FUNDING` (skips validate_debit/credit); the balance check was the lone inconsistency. Create-time passed because pos1's in-flight CCA→IVA credit counts as IVA `pending_credit`.

**Manual unblock (DONE, Kevin ran it):** set `transfer.metadata.update!(force_reason: USER_OVERRIDE, forced_by_user: kevin, force_note: ...)` then `Transfers::V2::StateService.complete!(transfer, receiving_payment_processor_transfer_id: metadata.initiating_payment_processor_transfer_id, initiator: Initiator.from_record(user))`. USER_OVERRIDE+forced_by_user bypasses all LE validation (`ledger_entry.rb:473`). `StepCompletionJob` keys off idempotency token, not force_reason, so relabel is safe.

**Fix = treasury PR #8586** (OPEN, MERGEABLE, signed, CI GREEN, NOT merged — do not merge without Kevin). Original bug author: Sam Felder (sf8193), #7692 Jun 2026 — added OUTGOING_PAYMENT_FUNDING to `ledger_entry.rb:484` debit/credit bypass but NOT to `ValidateBalanceService:9`, so balance check kept firing (half-wired bypass). Branch `kevinliang/ivc-pull-completion-balance-bypass` (worktree `.worktrees/treasury-ivc-balance`). One line: add `OUTGOING_PAYMENT_FUNDING` to the `ValidateBalanceService:9` bypass list + 2 specs. Passed pre-push gate: 2 clean rounds / 4 Opus agents (correctness, money-safety, refutation, test-quality). Money-safe: force_reason internal-only (no external input), pos N submits only after N-1 completes, every funding step is internal CA→CA (no external rail).

**Follow-ups (not in PR):** (1) misleading `base.rb:52-54` comment (pos1 also bypasses at completion via CROSS_TRANSFER default); (2) post-completion negative-cash alert (no ledger floor once bypassed); (3) integration test through `complete!`.
