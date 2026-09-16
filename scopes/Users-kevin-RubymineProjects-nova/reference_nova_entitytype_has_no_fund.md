---
name: reference-nova-entitytype-has-no-fund
description: "Nova's vulcan EntityType has no 'fund' value; a fund entity's Entity.type is 'llc'"
metadata: 
  node_type: memory
  type: reference
  originSessionId: cb150723-8a16-47fc-9f46-a1010134e6e4
  modified: 2026-08-27T22:01:01.551Z
---

The vulcan `EntityType` (`@angellist/nova-vulcan-schema`, the type of `Entity.type`) does NOT include `'fund'`. So a fund entity's nova `Entity.type` is `'llc'` (funds are structurally LLCs). Ipseity stores a fund as `company` + incorporation `LLC` + `meta_entity_type: 'fund'`, but that fund-ness has no distinct nova `EntityType` — `ipseityToNovaEntityType` correctly resolves it to `'llc'`.

Do NOT confuse this with `COMPANY_TYPES` in `graph/src/data/entityKyc/hardcodedEntityKycAmlSchema.ts` (`['corporation','company','fund','dao','llc','partnership','otherEntity']`) — those are KYC-form entity types, a different set that DOES include `'fund'`. Returning a COMPANY_TYPES value that isn't in vulcan `EntityType` (like `'fund'`) from a function typed to return `EntityType` fails the production `tsc` build.

Making funds a distinct nova type would require adding `'fund'` to the vulcan `EntityType` — a schema change, separate from the matchmaking port (BANK-1890).
