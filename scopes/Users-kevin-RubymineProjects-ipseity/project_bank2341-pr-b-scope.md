---
name: project_bank2341-pr-b-scope
description: BANK-2341 "PR B" (untracked follow-up to ipseity #1689) scope — raise IneligibleError at boundaries; ships under the same Linear issue
metadata:
  type: project
---

Kevin (2026-10-20): PR B is a follow-up PR under BANK-2341 itself, no separate Linear issue. Scope:
1. Raise `Entities::Verifications::IneligibleError` at the boundary (verifications_controller `alloy_verify`/`verify_identity`, any Prophet handler) — never from `AlloyService`.
2. Fix the blanket `rescue => e` at verifications_controller.rb:21 and :122 so it doesn't swallow ClientError.
3. Do the IRA → individual swap before computing reasons, or an IRA reports `unsupported_entity_type`.
4. Metric/log tag so a ClientError is visible in ipseity (BaseHandler#process now returns it as a Response, so Prophet logs "Request completed"). Callers' Prophet client still set_error's their span on any error response; that fix is caller- or prophet-gem-side.
5. Run the eligibility check after any per-entity permission check, or it tells the caller which identity fields are missing.
6. `IdentityService.can_verify?` returns true for US entities without asking AlloyService (identity_service.rb:8-10); the boundary must compute reasons itself, after the IRA swap.

**Why:** #1689 only builds the pattern; nothing raises yet.
**How to apply:** ship PR B only after treasury (pin bump, see treasury memory project_bank2341-client-error-contract), venture, and nova's ipseity mapper handle `verification_ineligible`; nova must key on `category`, not Prophet's `class`.

**Caller ship gate (found in PR B's gate, ipseity #1690):** venture has two `verify_identity` callers the original list missed. `backend/cptr/.../cptr/distributions/recipient_verification_service.rb:25` runs inside the distribution-create transaction with no rescue, so a 422 rolls back the whole distribution. `ipseity/entity/kyc_service.rb:69-70` (plus its `backend/banking/` copy) must rescue the 422 around `verify_identity!` only, so `verify_related_entities!` still runs. The Prophet `entities.finalize` handler was left alone on purpose, because raising there blocks onboarding submission.

**Kevin's decisions (2026-10-20):** keep the 422 `unsupported_region` for a non-US `alloy_verify`. Before, it ran Alloy anyway. Leave the Prophet `entities.finalize` handler unchanged.
