---
name: ipseity-ineligible-is-not-unverified
description: "ipseity's verification_ineligible (field-level reasons) is independent of KYC verified status; a flagged LP can still be verified and withdraw"
metadata:
  node_type: memory
  type: project
  originSessionId: 9581a2a1-f804-4f98-86df-2080d8db1983
  modified: 2026-10-30T20:37:35.603Z
---

ipseity `raise_if_ineligible!` (verifications_controller.rb) computes reasons purely from identity_data completeness (AlloyService.ineligibility_reasons: SSN, birthdate, address, shareholders flag) and never checks whether the entity is already verified. Verified status comes from stored kyc_aml_status flags (VerificationService.verified?), which treasury mirrors into CustomerAccount#verified? and uses to gate ACH pushes, wires and transfers.

So an LP on cptr's `ineligibleRecipients` list may be verified from an earlier check and can move money off platform. cptr's list is informational; distribution create still succeeds.

**Why:** On 2026-10-30 I first told Kevin "flagged LPs can't withdraw" by conflating the two; his "are you sure?" caught it.

**How to apply:** when asked what a verification error means for money movement, check treasury's `verified?` source separately; don't infer one from the other. Related: [[project_bank2341-pr-b-scope]], [[project_bank2341-client-error-contract]].
