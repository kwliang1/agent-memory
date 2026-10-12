---
name: ca228379-self-linked-ach-pulls
description: CA 228379 +$23,690 balance gap — CA 455373 linked 228379's own GHB account as an external ACH account and pulled $23,685; skill had no check for it
metadata:
  type: project
---

Diagnosed 2026-10-09 (read-only). Both CAs denylisted.

- +$23,685: CA 455373 (company, opened 2026-06-04) added EA 112087 = SA 173249's routing/account (FedNow 1¢ verify, IW 308446), then 12 AchPulls 553490..554170 on 6/5–6/8. Booked as EXTERNAL incoming to 455373; 228379 ledger never debited, bank was. 455373 still holds $24,685.04.
- +$5.00: IW 306080 provisioned; bank returned the $5 credit 5/18.
- Fix shape (not yet approved): ledger-only debit of 228379 for $23,685 before any restitution from 455373.

**Why:** [[balance-check-diagnosis-skill]] had no section for an ACH pull/push whose external account is a family sub-account; found only by matching `ExternalAchAccount.where(account_number:, routing_number:)` to the sub.
**How to apply:** on an unexplained gap of bank-only ACH debits named "AngelList ACH from G…", check that query first.

**Update 2026-10-09 (night):** Filed BANK-2271. `Maintenance::RepairCa228379BalanceCheckGapTask` is on branch `kevinliang/bank-2271`, worktree `.worktrees/treasury-2271`, commit 17dd6ead9, not pushed yet. Kevin approved including the IW 306080 return. The task runs over a one-row collection (CA 228379) in a single transaction with dry_run defaulting to true. It writes a DESTINATION_CHANGE audit LE (228379 → GA 91, USER_OVERRIDE, user 460 = Kevin), sets the deposit's `revised_origin`, and calls `return!` on the IW. The prod read-only preflight passes, and the projected full_internal_balance is $7,452.50, which equals TP. The IW check must use `sub_account_id`, not `original_sub_account`: `incoming_wire_adjustment` keys on `sub_account`. Specs run via a sibling container with DB suffix `_2271`.

**Update 2026-10-09 (late):** PR treasury#9119 is open as a draft and pushed at cfb010626. The gate took 5 rounds; rounds 4 and 5 were clean. Round 1 fixes: the dry run skips `return!`, because its `log_transition_success!` writes to S3 outside the transaction, and refusal-table specs were added. Round 3 fix: create fixed-id `let!`s (user 460, GA 91) before any factory that takes an auto-assigned id, because MySQL doesn't roll back AUTO_INCREMENT. Prod facts: GA 91 is Piermont program 17's EXTERNAL_INCOMING_FUNDS (a pre-existing quirk for GHB pulls) with no active sub; 228379 has no IVC and no holds. Next: Kevin reviews and merges, gives compliance/finance a heads-up, then runs it (the dry run logs $7,457.50 and the real run $7,452.50).
