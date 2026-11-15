---
name: reference_increase-openapi-field-patterns
description: Increase's per-field character sets and length limits are in its public OpenAPI spec (increase.com/openapi.json), not the HTML docs, which only say "character restrictions apply"
metadata:
  type: reference
---

The HTML API docs say only "character restrictions apply". The exact regex and min/max lengths are in `https://increase.com/openapi.json` (public, about 4MB; `api.increase.com/openapi.json` returns 401). Query it with `jq '.components.schemas.create_a_swift_transfer_parameters'`, and likewise for `create_a_wire_transfer_parameters`.

Values as of 2026-10-27:
- SWIFT text fields (names, address lines, city, state, postal code, remittance): `[a-zA-Z0-9/?:().,'+ -]`, the SWIFT "x" set.
- Domestic wire text: `[ a-zA-Z0-9.?!,;:_/@\&'"`~()<>#%+-=$]`.
- SWIFT `account_number` and `routing_number`: alphanumeric only.
- SWIFT `postal_code` max length: 16.

A reused idempotency key with a different body returns 409 `idempotency_key_already_used_error`.

Used for BANK-2421 (domestic) and BANK-2423 (SWIFT). Related: [[treasury-link-existing-increase-ca]].
