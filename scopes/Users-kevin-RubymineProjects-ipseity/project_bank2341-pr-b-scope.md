---
name: project_bank2341-pr-b-scope
description: Scope of the follow-up that makes ipseity raise IneligibleError at its boundaries, and the venture callers that must handle the 422 first
metadata:
  type: project
---

Kevin (2026-10-20) scoped the follow-up that makes ipseity actually raise the client-error pattern, under the same Linear issue as the pattern itself:
1. Raise `Entities::Verifications::IneligibleError` at the boundary (verifications_controller `alloy_verify`/`verify_identity`, any Prophet handler), never from `AlloyService`.
2. Fix the blanket `rescue => e` at verifications_controller.rb:21 and :122 so it doesn't swallow ClientError.
3. Do the IRA → individual swap before computing reasons, or an IRA reports `unsupported_entity_type`.
4. Metric/log tag so a ClientError is visible in ipseity (BaseHandler#process returns it as a Response, so Prophet logs "Request completed"). Callers' Prophet client still set_error's their span on any error response; that fix is caller- or prophet-gem-side.
5. Run the eligibility check after any per-entity permission check, or it tells the caller which identity fields are missing.
6. `IdentityService.can_verify?` returns true for US entities without asking AlloyService (identity_service.rb:8-10); the boundary must compute reasons itself, after the IRA swap.

**Why:** the pattern itself raises nothing yet.

**How to apply:** ship it only after treasury (pin bump, see [[project_bank2341-client-error-contract]]), venture, and nova's ipseity mapper handle `verification_ineligible`. Nova must key on `category`, not Prophet's `class`.

**Caller ship gate:** venture has two `verify_identity` callers that are easy to miss. `backend/cptr/.../cptr/distributions/recipient_verification_service.rb:25` runs inside the distribution-create transaction with no rescue, so a 422 rolls back the whole distribution. `ipseity/entity/kyc_service.rb:69-70` (plus its `backend/banking/` copy) must rescue the 422 around `verify_identity!` only, so `verify_related_entities!` still runs.

**Kevin's decisions (2026-10-20):** keep the 422 `unsupported_region` for a non-US `alloy_verify` (before, it ran Alloy anyway). Leave the Prophet `entities.finalize` handler unchanged, because raising there blocks onboarding submission.
