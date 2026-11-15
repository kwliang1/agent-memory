---
name: project_bank2341-client-error-contract
description: Treasury must read ipseity's client-error contract from entity_api (EntityAPI::ErrorCategory), not entity_prophet_api
metadata:
  type: project
---

Kevin ruled (2026-10-20) that ipseity's client errors are app-owned (`ClientError`, app/errors), never in a gem, and that a REST controller must not handle a Prophet-gem error. The wire strings live in `entity_api`: `EntityAPI::ErrorCategory::HEADER` ('X-Error-Category') and `::VERIFICATION_INELIGIBLE`. `entity_prophet_api` has no client-error classes.

**Why:** an earlier treasury plan read `EntityProphetApi::Errors::ClientError::CATEGORY_HEADER`; those constants no longer exist after ipseity's redesign.

**How to apply:** treasury #9216 (2026-10-22) bumped to ipseity 4e5176eb / entity_api 0.46.0 and reads `EntityAPI::ErrorCategory` in app/services/entities/verification_ineligible_error.rb; add new categories there, not as local strings. The spec helper (spec/support/ipseity_error_helper.rb) deliberately uses the literal wire strings, not the constants, so a drifted constant fails CI. The pattern is documented in ipseity AGENTS.md "Client Errors (both transports)". Related: [[entity-api-bump-regenerates-two-gem-rbis-and-dsl]].

**Gate lesson:** ipseity main's `verify_identity` answers **true** (not false) for an ineligible entity, so any "keep today's behaviour" claim must keep running the related-party loop and `update_verification!` after an owner's 422.

**UI round (2026-10-22):** Kevin chose a `<Stack gap='50'>` per line in `createErrorToast` (frontend/lib/errors.tsx) via `as unknown as string`, over a type-safe `white-space: pre-line` CSS rule: adapt 59.5.3 types `ToastConfig.description` as string but renders it inside a div `Text`. Facts that took digging: ipseity `AlloyService.verify_on_alloy?` returns true for every entity, so treasury's `verify_watchlist`/`verify_adverse_media` party branches are dead; and treasury's catch-all GraphQL `rescue_from(StandardError)` logs `err.message`, so any error carrying party names belongs in the unlogged expected-errors handler.
