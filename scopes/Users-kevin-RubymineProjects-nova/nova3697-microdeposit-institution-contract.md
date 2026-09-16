---
name: nova3697-microdeposit-institution-contract
description: "NOVA-3697 microdeposit \"plaid_institution_id is invalid\" = app-side Prophet contract mismatch, not Plaid; manual-entry flow has no institution."
metadata: 
  node_type: memory
  type: project
  originSessionId: 4929c665-9014-4a65-a38f-81cc8f6fcf16
  modified: 2026-08-03T22:50:58.492Z
---

NOVA-3697 (CF Distribution): RUM error `CreateMicrodepositVerification … plaid_institution_id is invalid` (replay bca70095-fca7-450c-9cc3-0180383c3f09, 2026-08-03 19:02 UTC, user Don Craven Jr).

**Root cause = application side; Plaid never called** (treasury rejected input in 6.8ms). Contract mismatch across 3 layers:
- Frontend `app/src/components/shared/PlaidFlowProvider/index.tsx:206` sends `plaidInstitutionId: metadata.institution?.institution_id` → `null` in Plaid's **manual account/routing micro-deposit** flow (`verification_status = pending_manual_verification`, no institution selected).
- nova GraphQL `createMicrodepositVerification.ts:20` = `required: false` (optional).
- treasury domain `Plaid::MicrodepositVerifications::CreateService` = `T.nilable(String)` (optional, stores on nullable `Plaid::BankConnection` col).
- treasury Prophet contract `treasury_prophet_api/.../messages/microdeposit_verification.rb:29` `const :plaid_institution_id, String` = **required non-nil** ← the lone outlier that rejected it via `base_handler.rb:174 validate_input_shape!`.

**Fix** = make Prophet struct `T.nilable(String)` (align with service + GraphQL). No RBI regen needed (plain gem file, no tapioca DSL). SHIPPED as **treasury PR #8431** on branch `kevinliang/nova-3698` (sub-issue NOVA-3698, assigned Kevin); rspec plaid_handler_spec 22 pass + srb tc clean + 2 independent clean review rounds.

**Replay can't confirm the manual-entry path**: Plaid Link is a cross-origin iframe, and Datadog session replay does NOT record cross-origin iframe DOM — the Plaid modal is a blank rectangle in every AngelList replay. Manual-entry conclusion rests on the request payload (null `plaid_institution_id` AND null `bank_name`, both from Plaid `metadata.institution`) + `pending_manual_verification`. Only Plaid's own dashboard would prove it airtight.

**Why "not alerted"**: classed `client:treasury:invalidRequest` (4xx-shape, no page) + frontend catch swallows to `Result.ok(false)` + handled RUM error (`index.tsx:247`); UI advanced to `?step=all-set` while link silently failed. Only surfaced via Jack Plank RUM signal digest.

Open sub-issue: stuck tooltip blocking field input = separate frontend UX bug (couldn't see screenshots — bridge doesn't relay attachments, see [[slack-attachments-thread-reply-bug]]).
