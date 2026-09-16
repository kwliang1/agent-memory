---
name: inc5355-nsf-classifier-removal
description: "INC-5355 P0 NSF classifier removal — PR #8350 supersedes #8343; always page on V2 errored transitions"
metadata: 
  node_type: memory
  type: project
  originSessionId: a2998926-ae78-4ad4-8652-8b27ff2fb72b
  modified: 2026-07-24T18:44:07.411Z
---

INC-5355 (P0, 2026-07-24): 8 FUNDS_MIGRATION TreasuryPrime ACH self-transfers (CA 439789 + 334035) errored terminal with TP's "Non-sufficient funds." string, paging a P0. Root cause of the *page*: `Transfers::V2::StateService#insufficient_funds_error?` regex-matched only `/insufficient funds/i` + `/not enough funds/i` to DOWNGRADE NSF to non-paging `ErrorTracker.error`; "Non-sufficient funds." didn't match → fell to critical → paged.

**Two PRs:** #8345 (merged) = remediation task re-created the 8 errored transfers. #8343 (sky-agents, open) = wanted to ADD `/non-?sufficient funds/i` to SUPPRESS the page.

**Decision (from Slack thread C0BKKP8G2KU, Harsohail + Kevin):** #8343 is NOT worth it. `INSUFFICIENT_FUNDS_ERROR_PATTERNS` is an anti-pattern → REMOVE it. Post-initiation NSF should ALWAYS page. My PR **#8350** (branch kevinliang/inc-5355-remove-nsf-classification) removes the constant + `insufficient_funds_error?`, collapses `log_errored_transition` to always `ErrorTracker.critical`. Commented on #8343 recommending closure.

**Key reconciliation ("sufficient balance vs NSF" — both true):** expected shortfall → QUEUED upstream by `QueueingService#check_if_insufficient_payment_processor_balance` (queueing_service.rb:37-59), never reaches `error!`. So an NSF at `error!` = pre-submit check passed but bank rejected = balance-model divergence. These transfers were ACH CREDITS (create_service.rb:155-159: Debit only for `from_sub_account.svb? && ACH`), so balance-checked → genuine divergence, NOT benign external-debit. Kevin's RCA: no funds misdirected, alert-severity bug only.

**Empirical volume (Sentry, 90d):** old non-paging NSF message `'Transfers V2 transfer failed due to insufficient funds'` = ZERO issues; critical `'Unexpected error in Transfers V2 state change'` = 3 issues (TREASURY-68Q=INC-5355 8 events; 66D 3; 5JS 10), all incident-shaped. So always-paging adds ~zero new page volume — no storm.

**Gate:** 5 rounds review (Kevin wanted 3 consecutive clean). Rounds 3+5 fully clean 3/3; round 4's ops "quantify volume" concern resolved by the Sentry data above. Sorbet clean, spec 47/47 (mocks off).

**Follow-ups (documented in PR, NOT done):** (1) V1 `NetworkTransfer` retains identical downgrade at `webhook_service.rb:333-337` (separate legacy state machine, TP-being-removed path) — left out of scope. (2) `execute_job.rb` discard_on block guards with `next if transfer.executed?` not `can_error?` — pre-existing, add for consistency if desired. See [[bank1592-self-transfer-fix]] [[svb-funds-migration-sla]].
