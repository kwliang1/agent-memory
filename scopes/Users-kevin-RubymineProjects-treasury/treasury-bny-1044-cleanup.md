---
name: treasury-bny-1044-cleanup
description: "$10.44 BNY test-sub cleanup (incident 2026-08-04): PR #8784 one-shot MT with two chained V2 transfers Piermont 490735 → closed BNY 501802 → GHB 515747; run once via UI after merge, watch the auto-sweep race"
metadata: 
  node_type: memory
  type: project
  originSessionId: ad7c38f6-2d49-4905-b9e2-9bdcaa741c20
  modified: 2026-09-03T21:05:13.734Z
---

Incident (Slack C0BN3027A6Q/p1785862411388079, 2026-08-04): the 2026-07-08 "erroneous transfer" was `BalanceChecks::ResolutionService` auto-heal (LE 5730975) sweeping the whole $10.44 physical balance off the closed DIBS/BNY test sub-account 501802 (CA 411006 Rollups Reserve, closed 2026-04-27) onto the active DIBS/Piermont sub 490735. It fired because SA 490735's balance checks failed daily by exactly $5.44 until 2026-07-15 (then `naturally_resolved`; the sub aged out of the daily check set — checks only cover subs active in the last 7 days, so OUR transfers put it back in). Flipper `balance_check_auto_heal_inactive_subaccounts` is ON; Kevin declined toggling it for the run.

Fix = **PR #8784** (`kevinliang/inc-1044-bny-cleanup-transfers`): `Maintenance::ReturnBnyTestFundsToFboInvestorsTask`, two chained V2 transfers — (1) FUNDS_MIGRATION 490735→501802 $10.44 (forwarder skips funds migrations), (2) cross-CA TRANSFER 501802→515747 (CA 468599 FBO Investors, TP/GHB) with `waiting_on_transfer` on (1). Both route as real DIBS ACH (`bny_transfer` in determine_payment_type! bans Book when either side is dibs_bny; DIBS can't network-transfer). Tokens `return-bny-test-funds-sa490735-to-sa501802-1044-v1` / `...-sa501802-to-sa515747-1044-v1`.

**Run plan:** merge → run ONCE via /maintenance_tasks → verify both transfers complete, SA 501802 dibs_balance $0, CA 468599 +$10.44. Residual accepted race: while the $10.44 physically rests at BNY (hop-1 settle → hop-2 ACH submit), any FAILING balance check on 490735 re-arms the sweeper. If hop 1 errors, hop 2 parks queued on InsufficientPaymentProcessorBalance — cancel it manually.

Review-loop lessons (4 reviewers, 7 rounds): the stranding class = validations that exempt FUNDS_MIGRATION but hit the chained second transfer at create/completion after hop 1 dispatched — mirror keys off `account_purpose` (transfer.rb `validate_mirror_transfer`), NOT the IVC linkage; denylist + IRA are create-time; hop 2's `sufficient_balance` checks CA-level ledger `available_balance`, not any sub's bank balance; `force_note` is load-bearing for the FUNDS_MIGRATION balance bypass (`force_reason.present? && force_note.present?`). A reviewer's "missing dibs_counterparty_id" finding was WRONG — `Transfers::V2::BaseStateService.submit!` auto-registers counterparties via `DIBS::Client.set_up_sub_account_counterparty!`. Related: [[funds-migration-autoforward-stranding]], [[treasury-prod-console-access]].
