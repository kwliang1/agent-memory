---
name: account-merge-strands-inflight-ach-pulls
description: CustomerAccounts::MergeService re-points in-flight (provisioned) ACH pulls to the target CA but leaves their sub_account and cash on the from-CA; completion then fails forever on sub_accounts_compatibility
metadata:
  type: project
---

`CustomerAccounts::MergeService` re-points in-flight (`provisioned`) ACH pulls to the target CA but leaves their `sub_account_id`, and their DIBS cash, on the from-CA's sub. `transfer_funds!` moves `from.balance`, which excludes that in-flight cash, and `merge_external_accounts_and_external_payments!` `update_all`s the pulls' customer_account_id + EAA. On completion the forward builds `origin: <target CA>, from_sub: <from-CA's sub>`, `Transfer#sub_accounts_compatibility` raises, and the completion rolls back on every attempt.

Kevin's rules: **never move sub accounts between CAs**. The repair is to point the pulls back at the from-CA, let them complete, then sweep through `MergeService.transfer_funds!` and point them back at the target. The real fix belongs in MergeService (refuse to merge while payments are in flight), not in the forward.

Spotting it: an AchPull whose `sub_account.account_id != customer_account_id`. Forward LEs also double-credit the active sub at sub-ledger level (completion LE `to_sub` = active sub, plus the forward), which is pre-existing for every forward.

Related: [[ach-pull-cross-ca-sub-landing]], [[treasury-prod-console-access]].
