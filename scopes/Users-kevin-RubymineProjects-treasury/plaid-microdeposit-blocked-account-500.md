---
name: plaid-microdeposit-blocked-account-500
description: "treasury create_microdeposit_verification returns 500 on Plaid BANK_TRANSFER_ACCOUNT_BLOCKED; should be 422 — and the venture FE promise never settles, so the Plaid modal hangs"
metadata:
  node_type: memory
  type: project
---

Investigated 2026-09-15 from a Datadog trace (`17595480567182605522`, Sep 09 2026).

**Chain:** venture `POST /venture/graphql` → treasury `POST /api/plaids/create_microdeposit_verification` → Plaid `POST /item/public_token/exchange` → **400** `BANK_TRANSFER_ACCOUNT_BLOCKED` / `BANK_TRANSFER_ERROR` ("bank transfer was blocked due to a previous ACH return on this account"). treasury-web span is **500**.

Code path: `treasury app/controllers/api/plaids_controller.rb:94` → `app/services/plaid/microdeposit_verifications/create_service.rb:31` → `app/services/plaid/api_service.rb:82`. No `rescue Plaid::ApiError` → `Api::Controller#uncaught_exception` (`api/controller.rb:142`) → Sentry + 500 + raw Plaid dump as body.

**Should be 422, not 500.** Plaid docs: not retryable, caused by end-user account state. 422 specifically (not 409) because the protip client only types 422 → `Protip::UnprocessableEntityError` and 404 → `NotFoundError`; everything else is a generic `Protip::Error` string blob (`protip/client.rb:34-40`). 409 in treasury is reserved for "reroute via another rail" (`api/controller.rb:118-124`).

Fix machinery already exists: `HttpStatusError` (`app/models/concerns/http_status_error.rb`), precedent `Applications::MoneyMarketFunds::CreateService::AccountApplicationError` → `:unprocessable_entity`; its `report_to_error_tracker?` default of false also stops the bogus Sentry page. Gate on `Plaid::ApiService.parse_plaid_error_code` (`api_service.rb:166`) with an allowlist like `IDENTITY_EXPECTED_ERROR_CODES` (`api_service.rb:19`) — Plaid 5xx/rate-limit must STAY 500.
**Gotcha:** `http_status_error` renders JSON, not a protobuf `Protip::Messages::Errors`, so a caller doing `e.errors` breaks (`venture app/services/startups/closing_details/create_service.rb:158` does that on another endpoint). Read `e.response.body` instead.

**Bigger bug than the status code — the FE hangs.** Nothing catches the throw: venture mutation has no rescue (`app/graphql/mutations/venture/plaid/create_microdeposit_verification.rb:75`); FE wrapper has no try/catch (`frontend/fundraising/components/PlaidFlowProvider/LaunchLink/functions.ts:94`); `onSuccess` awaits it at `PlaidFlowProvider/index.tsx:119`, so `resolver.current?.(...)` (:123) and `clear()` (:132) are skipped; `triggerPlaidFlow` returns a promise with **no reject path** (:77-79). Promise never settles, `loading` never clears. The file's own doc comment at `:45` claims it "will return false if an error was thrown" — false. Surfacing hook already present: `DetailedExecutionError` is used in that same mutation at `:31`.

**Volume:** DD Error Tracking issue `b51eb80e-5e0f-11f1-a051-da7ad0900002`, team Nova Foundations, service `treasury-web`, `error.type:"Plaid::ApiError"` — 6 occurrences, clustered mid-Aug → Sep 9 2026. Error code verified on one sample only.

Related: [[treasury-prophet-datadog]], [[ter-37-unauth-treasury-webhooks]].
