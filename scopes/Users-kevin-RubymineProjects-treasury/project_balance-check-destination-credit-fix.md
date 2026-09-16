---
name: balance-check-destination-credit-fix
description: PR
metadata: 
  node_type: memory
  type: project
  originSessionId: 6a9fc69b-9665-4f56-aeca-dfebf1ff3b16
---

PR #8146 (branch `kevinliang/fix-balance-check-destination-credit`, 2026-07-08): deleted `transfer_v2_destination_credit_adjustment` (speculative SLA-gated credit that minted ~198 false positives in run `edb567b1-7f56-4a4a-8780-2e7a3ee2bfe0`), partitioned `transfer_v2_origin_debit_adjustment` by `from_sub_account` (active SA: TP Processing/SPA, DIBS Submitted/Processing/SPA; non-active SA: all pending states). Flipper `external_payment_processor_balance` is OFF until this ships.

**Why:** V2 ledger entries post atomically with Completed; completion IS the observation of the receiving bank's credit — no state-based destination credit can be correct. DIBS sub-ledger debits origin at PT provision (= submit) and stays debited, so the old "DIBS Processing would double-count" comment was wrong.

**How to apply / outstanding:**
- Replay DONE (Kevin ran it, 2026-07-08): 350/363 records match baseline; 256/266 minted come back clean (predicted 255). Expected next run ~125 records. CI green, Devin clean.
- Follow-up tickets needed: (1) CA 460853 — $50k old-method-masked real mismatch surfaced by the fix (outgoing Created/Queued from active SA, bank $0); (2) CA 199865 stuck-submitted BookTransfer + CA 5307 stuck AchPush data fixes; (3) 4 SPA transfers pending >7 days (incl. a 97¢ disbursement, transfer 173374) — glance before flipper re-enable.
- [[al-console-treasury-rbac]] is FLAKY, not hard-blocked — `al console exec` intermittently succeeds (~1 in 18 attempts); retry loops work for staging files.
- SLA helpers (`evaluate_transfer_sla`, `BalanceCheck::SlaLevel`) are now UNCALLED but deliberately kept — Kevin owns them in another session; don't delete as dead code.
- Straggler records CA 5307 (AchPush stuck submitted, DIBS PT likely rejected) and CA 199865 (BookTransfer stuck submitted, lost webhook) are data fixes, not code.
- Pre-existing bug found in review (needs ticket): `sub_account_ids_checked_in_last_7_days` (check_service.rb) can re-pull an MMF sub-account into the pool → unguarded `external_balance` raise outside `run!` rescue.
