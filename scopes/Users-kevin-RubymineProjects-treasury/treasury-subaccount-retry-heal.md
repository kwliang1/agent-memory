---
name: treasury-subaccount-retry-heal
description: Treasury stranded-account (no sub-account) reactive heal via RetryService on next transfer; why the FBO-create partial-creation edge is NOT ticketed
metadata: 
  node_type: memory
  type: project
  originSessionId: 8ca5de24-4905-41da-9096-4e2cb5da7f33
  modified: 2026-08-03T15:59:06.038Z
---

Treasury `CustomerAccounts::CreateService.create!` commits the CustomerAccount (+FboIdentity) then runs `perform_post_creation_setup!` (creates a `SubAccountRequest` + kicks a Temporal `ProcessWorkflow`) with NO wrapping txn. If setup raises after `save!` — transient Temporal workflow-start failure (re-raises at `sub_account_requests/create_service.rb:76`), or `SubAccountRequest` DB-write fail — the account is left with no sub-account, and the idempotent early-return (`create_service.rb:52-55`) returns it as-is on retry, never re-running setup. FBO is excluded from the `verification.rb:66` self-heal (`return if fbo?`).

**Mitigation (the key non-obvious fact):** `SubAccountRequests::RetryService.retry_failed_for_transfer_creation!` (called from `transfers/v2/create_service.rb:53` on `Transfer::CreationError` "No active sub account found", `transfer.rb:108/116`) re-drives the most-recent `Failed` SubAccountRequest for that account (cap 10, skips if in-flight, never raises). **No fbo? exclusion — it covers FBO.** So a stranded account self-heals on the next transfer attempt; otherwise it fails CLOSED at transfer time (no silent money movement). No proactive cron; visibility = "Sub Account Request Failures" panel on the banking Datadog dashboard.

Gap NOT covered: a bad `partner_bank_program_name` makes `resolve_fbo_program!` raise BEFORE any SubAccountRequest exists → nothing for RetryService to retry (still fails closed).

**Decision (2026-08-03, Kevin):** this partial-creation edge is NOT worth a ticket — reactively healed + fails-closed is acceptable. Don't re-file it. Documented in PR #8305 body instead.

Shipped in [[nova-fund-onboarding-script]] sibling work: PR #8305 / BANK-1666 (FBO create over Prophet, 1/2) landed after adversarial review — added `owner_type`-scoped `RecordNotUnique` rescue so an FBO request never resolves to a non-FBO row on the fallback path. Commit `86827365b`, signed/verified.
