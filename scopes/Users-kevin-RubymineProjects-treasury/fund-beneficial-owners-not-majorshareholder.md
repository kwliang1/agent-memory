---
name: fund-beneficial-owners-not-majorshareholder
description: Fund 25%+ LP owners must not be written as ipseity MajorShareholder rows; BANK-2075 chose a new Roles::BeneficialOwner; callback presenter key bug
metadata:
  type: project
---
Fund (LLC) 25%+ beneficial owners are computed by venture's cap table (`CPTRApp::LlcService#related_banking_entity_for_fund`). Writing them as ipseity `Roles::MajorShareholder` is unsafe (investigated 2026-11-02 for BANK-2597): ipseity verification requires every MS to be verified (verified funds flip, blocks wires), IRA owners crash `verified_owner?`, Increase eligibility/`sync_with_bank!` require each MS's SSN/DOB (Increase policy, not Piermont), LP PII leaks to fund readers incl. nova GPs, KYB/nova forms and a sync each replace all roles, role writes emit no event. BANK-2075 already picked a new `Roles::BeneficialOwner`.

Kevin doesn't want to extend the AngellistCallbacks pattern; v1 direction is venture pushing owners at MMF submit via a new Prophet route (venture caller: `backend/banking/.../create_mmf_account.rb`).

Separate bug: `lib/presenter/customer_account.rb:43` reads the callback hash with a symbol key but Faraday JSON returns string keys, so beneficial owners have been nil since #4373 (2024-06); `info_service.rb` advisor lookup has the same bug.

**Why:** avoid re-deriving the side-effect sweep. **How to apply:** for any beneficial-owner sourcing question, start here and [[treasury-mock-ipseity-not-mock-entity-api]].
