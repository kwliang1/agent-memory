---
name: plaid-sync-balance-500-attribution
description: How to find the affected CustomerAccount for a treasury Plaid sync_transactions balance-500 trace (item_id is never logged)
metadata: 
  node_type: memory
  type: reference
  originSessionId: 837c506a-11ff-4072-8338-46b18b7afe42
  modified: 2026-07-23T23:35:14.737Z
---

Treasury `Api::PlaidsController#sync_transactions` is the ONE Plaid action that skips `instrument_params`, so the `plaid_item_id` never lands on any span. ~~Treasury ships no app logs to Datadog~~ WRONG (re-verified 2026-10-05): treasury-web/-web-ro/-prophet/-worker/-temporal Rails logs ARE in Datadog Logs (`service:treasury*`); `Rails.logger` lines are searchable. The Sentry event (issue `TREASURY-405` "Error occurred while trying to query balance on Plaid" → `BANK-963`) captures only the raw Plaid response, not the connection/account. So a `/accounts/balance/get` 500 trace gives you no direct account id.

**Flow:** Plaid `TRANSACTIONS/SYNC_UPDATES_AVAILABLE` webhook → venture `PlaidApi::WebhookController#create` (`/plaid_api/webhook`) forwards → treasury `sync_transactions` → `TransactionSyncService` → `BalanceService.refresh_bank_connection_balances!` → Plaid balance/get. On `Plaid::ApiError` the `rescue` (balance_service.rb ~line 96) does NOT re-raise: it writes `status=CANNOT_USE, error_code=UNKNOWN_FAILED_WHEN_CALLING`, reports to Sentry, returns false. Request COMMITS with HTTP 200; the errored APM span is just `ErrorTracker` tagging, not a rollback. Balance failure is isolated — transaction sync still works; a stale/transient Plaid 500 often self-heals on the next refresh.

**Attribution recipe (prod console):** the whole sync usually commits nothing (cursor unchanged → no `Plaid::TransactionUpdate` row; no-op `update!` doesn't bump `updated_at`), so time-correlation fails. Instead:
1. Candidates = external-vault (`ExternalVaultAccountSetting.exists?(external_vault_account_id: customer_account_id)`) `Plaid::BankConnection.where(status: "CANNOT_USE", error_code: "UNKNOWN_FAILED_WHEN_CALLING")`.
2. A `SYNC_UPDATES_AVAILABLE` webhook fires only on live txn activity, so rank candidates by recent `plaid_transaction_updates` count (last ~14d). Usually exactly one is alive → that's the affected `CustomerAccount` (the external-vault account itself; `bank_connection.customer_account`).
3. 100% confirm via Plaid Dashboard: item webhook history should show `SYNC_UPDATES_AVAILABLE` at the trace timestamp.

**Sticky-flag bug (latent):** the balance-500 `rescue` immediately + permanently sets `CANNOT_USE`/`UNKNOWN_FAILED_WHEN_CALLING` even for a transient Plaid 500. Nothing self-heals it — balance-success does NOT reset status; `STABLE` is only set on re-link (`ach_account_service.rb:33`) or microdeposit create. Downstream while stuck: (1) `external_vault_accounts/info_service.rb:36` generates a Plaid "update mode" token → customer sees an unnecessary "reconnect your bank" prompt though the link works; (2) scheduled `rake plaid:refresh_bank_balances` only processes `STABLE` → skips it (balance then only refreshes via inbound sync webhooks). Fix idea: flag `CANNOT_USE` only on terminal codes (ITEM_LOGIN_REQUIRED) or N consecutive fails, and/or reset STABLE+clear error_code on next balance success.

**Fix shipped (2026-07-23):** PR #8339 (balance_service fix) + stacked PR #8340 (maintenance task `Maintenance::RecoverStrandedPlaidBankConnectionsTask`, dry_run defaults true, scoped to error_code UNKNOWN_FAILED_WHEN_CALLING). Branch `kevinliang/bank-963`. Classify transient off HTTP status (`error.code`, gem always sets it even for unparseable outage bodies): 5xx or 429; plus transient error_code allowlist. **Verified transient codes** (Plaid docs https://plaid.com/docs/errors/institution/ + treasury prod data): `PRODUCT_NOT_READY`, `PLANNED_MAINTENANCE`, `INSTITUTION_DOWN`, `INSTITUTION_NOT_RESPONDING`, `INSTITUTION_NOT_AVAILABLE` (all Temporary/HTTP400). **Terminal — keep CANNOT_USE**: `INSTITUTION_NO_LONGER_SUPPORTED`, `INSTITUTION_REGISTRATION_REQUIRED`, `ITEM_LOGIN_REQUIRED`, `NO_ACCOUNTS`, `ITEM_NOT_SUPPORTED`, `MFA_NOT_SUPPORTED`, `INVALID_CREDENTIALS`, `USER_PERMISSION_REVOKED`. Lesson: ground an allowlist in docs+prod data BEFORE writing it (Kevin caught this). op-ssh-sign `%G? N`/allowedSignersFile errors are LOCAL-verify-only noise — commits ARE signed (GitHub showed verified:true); don't conclude signing is broken from local `%G?`.

Console access: read console (`treasury-ro` ns) is Forbidden for my SSO role — use `/Users/kevin/bin/al console exec -a treasury -p -w -- bin/rails runner '...'` (write console, read-only queries fine). `al` is at `/Users/kevin/bin/al`, not on PATH. See [[treasury-prod-console-access]], [[incoming-wire-return-automation-gap]].
