---
name: project_bank2341-client-error-contract
description: BANK-2341 treasury caller must read ipseity's client-error contract from entity_api (EntityAPI::ErrorCategory), not entity_prophet_api
metadata:
  type: project
---

Kevin ruled (2026-10-20) that ipseity's client errors are app-owned (`ClientError`, app/errors), never in a gem, and that a REST controller must not handle a Prophet-gem error. The wire strings live in `entity_api` 0.46.0: `EntityAPI::ErrorCategory::HEADER` ('X-Error-Category') and `::VERIFICATION_INELIGIBLE`. `entity_prophet_api` has no client-error classes.

**Why:** the earlier treasury plan (option 2) read `EntityProphetApi::Errors::ClientError::CATEGORY_HEADER`; those constants no longer exist after ipseity #1689's redesign.

**How to apply:** on treasury branch `kevinliang/bank-2341-treasury`, after #1689 merges, bump the ipseity pin and replace the hand-copied `CATEGORY`/`CATEGORY_HEADER` in app/services/entities/verification_ineligible_error.rb with the `EntityAPI::ErrorCategory` constants; regenerate treasury's entity_api gem RBI. The pattern is documented in ipseity AGENTS.md "Client Errors (both transports)". Related: [[entity-api-bump-regenerates-two-gem-rbis-and-dsl]].

**2026-10-21:** Kevin chose to ship treasury with the hand-copied strings (PR #9213) rather than wait for #1689; swapping to `EntityAPI::ErrorCategory` is a follow-up. The spec helper (spec/support/ipseity_error_helper.rb) deliberately uses the literal wire strings, not the constants, so a drifted constant fails CI. Gate lesson: ipseity main's `verify_identity` answers **true** (not false) for an ineligible entity, so any "keep today's behaviour" claim must keep running the related-party loop and `update_verification!` after an owner's 422.
