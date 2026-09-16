---
name: bank-1764-ach-pull-block-submission
description: "BANK-1764 SHIPPED (treasury PR #8454): block ACH pull submission for denylisted/inactive CAs at 3 live chokepoints before bank contact. CI green, awaiting human review, NOT merged."
metadata: 
  node_type: memory
  type: project
  originSessionId: 1b78bb6d-2416-4c63-947a-522d848a2acd
  modified: 2026-08-18T15:47:47.657Z
---

BANK-1764 (follow-up to BANK-1719/#8443). Block ACH **pull** SUBMISSION for denylisted (`Denylist::CUSTOMER_ACCOUNT_NO_TRANSFER`) or deactivated (`active=false`) customer accounts — mirrors the existing AchPush `block!`. Branch `kevinliang/bank-1764` off main. **PR angellist/treasury#8454.**

**Status (as of 2026-08-18):** OPEN, base `main`, all CI green, `mergeStateStatus: CLEAN`, `MERGEABLE` (no conflicts). **APPROVED by @dcetlin (bare approval, zero comments).** Ready to merge — one click. **NOT merged — do NOT merge without Kevin's explicit go-ahead.** No worktree checked out (branch is local + remote only); spin one up only if feedback needs code changes. PR description was tightened 2026-08-13 (38→27 lines).

**What landed** (NOT the literal option 1/2 in the ticket — both had a money-safety hole): restricted pending pulls transition to `blocked` *before any bank contact* at 3 live submission chokepoints:
- `AchPulls::StateService.submit!` (DIBS) — new `block!` + `block_if_restricted!`
- `TreasuryPrime::SubmittableAchs::StateService.submit!` *before the TP POST* (TP posts before the pull service runs), pull-scoped
- `OutgoingAchFile#create_and_upload_aches!` now honors `submit!`'s return so a blocked pull is excluded from the SVB file (also fixes a pre-existing latent bug where a `blocked` pull was still filed = reconciliation break worse than status quo — round-1 review caught this)

`block!` mirrors AchPush's but skips the ledger reversal (a `created` pull has no provisional funds yet). Emits `treasury.ach_pull.blocked_at_submission` statsd + escalates if a restricted pull is somehow unblockable.

**Gate passed:** 144 specs (`unset MOCK_ENTITY_API && bundle exec rspec`), Sorbet clean, signed commit. 7 independent Opus reviews / 4 rounds → converged clean; 3 self-labeled non-blocking nits (dead/no-money paths) declined with reasoning in PR.

Prior sessions: atlas (built+shipped), flint (respawn — re-armed PR watch, polling). See [[treasury-local-dev-gotchas]].
