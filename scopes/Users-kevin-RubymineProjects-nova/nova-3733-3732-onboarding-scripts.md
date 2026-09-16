---
name: nova-3733-3732-onboarding-scripts
description: "NOVA-3733/3732 fund onboarding console scripts delivered — resolved control-person ipseity ids, FlowDash identity-data gaps, bank-program choice. Scripts drive the bank-1667 onboardVehicleAccounts engbot."
metadata: 
  node_type: memory
  type: project
  originSessionId: b5da6a07-d7a3-4ac9-b533-99c08b04fcc1
  modified: 2026-08-07T21:18:00.873Z
---

Delivered (2026-08-06) two prod-console scripts driving `EngBot.OnboardVehicleAccounts` (branch `kevinliang/bank-1667`, see [[bank-1667-pr9007-state]]). Scratchpad: `nova_3733.js`, `nova_3732.js`. Structure: STEP 1 `.plan(args)` = read-only dry-run; STEP 2 `.call(args)` = real (commented out). 3 review rounds passed.

**PR angellist/nova#9347** (branch `kevinliang/nova-3733-3732-onboarding` off main) was REPURPOSED (2026-08-07) from the runbook to a small engbot fix. Final state (per Kevin's review): **REMOVE `OnboardVehicleAccounts.plan()`'s vehicle entity-type check entirely** (a `corporation`-typed vehicle hit the old `type === 'fund'` gate; Kevin: "we shouldn't care about the type for this script"). Dropped the check + unused `entityTypeSchemaZod` import (net -6). Remaining plan() guards stay. Signed, off-draft, open. The runbook `.md` is NOT committed; the two onboarding scripts live only in the Discord thread.

**#9007 (bank-1667 engbot) MERGED to main 2026-08-06** — supersedes [[bank-1667-pr9007-state]]'s "awaiting review"; the enhanced engbot + fund gate are on main; branch `kevinliang/bank-1667` deleted.

For an immediate unblock (no deploy), Kevin temporarily set the vehicle's `entity.type='fund'` in prod console (functionally identical: only plan() reads type). Alt live-override: subclass `EngBot.OnboardVehicleAccounts` overriding static `plan()` — `.call()` uses `this.plan` + inherited `_perform` (action.js:81,90).

**Engbot call contract** (callSchema): `vehicleEntityId` (raw Entity UUID or `veh_…`; decodes via `uuids.veh.decode(val)||val`), `testModel`, `identityData{name,ein,incorporationState,incorporationDate,addressStreet,addressCity,addressState,addressPostalCode,country}`, `signatoryIpseityEntityId` (required), `controlPersonIpseityEntityId` (optional, defaults to signatory → same person gets BOTH roles), `beneficiaryName`, `accountPurpose:'INVESTMENT'`, `partnerBankProgramName`. `getOrCreateIpseityEntity` creates the fund's ipseity entity if missing.

**Resolved control-person ipseity entity ids** (both Verified in treasury):
- NOVA-3733 (Thursday Ventures 1X Holdings 4 LLC): Chase Keesling = `01980f70ed5578398a42ce2c1a3a7753` (treasury CA 411462). Org `a3ef9881-41d0-42a7-9301-2448ce0f2a78`, vehicle hint `e_UbM3fVtDAm`.
- NOVA-3732 (AngelList EI, LLC): Erik Syvertsen = `09e347616f84447699516d942af0a35e` (resolved from treasury CA 14339's Entity ID / `owner_entity_api_id`). Org `6099271b-d1bd-4c14-a832-01afe518f0cb`. Ticket gave NO vehicle id → scripts resolve the `fund`-type vehicle from the org by exact name match.

**Data gaps flagged to Kevin (must fill/confirm before running):**
- 3733 EIN: FlowDash "Fund EIN" mis-entered as "COO & Principal"; real EIN in the `CP_575_B` PDF. Script hard-stops (null guard).
- 3733 zip: FlowDash empty. Script hard-stops.
- 3732 city/state: FlowDash empty; scripts pre-fill San Francisco/CA from zip 94111 + "90 Gold St" (flag: 90 Gold St is sometimes 94133) — confirm vs formation doc.

**Bank program:** scripts pass `partnerBankProgramName='Increase (Grasshopper Bank)'` = `DIBS_INCREASE_GHB_NAME`. For `source=nova` FBO, treasury `resolve_fbo_program!` HONORS the requested name via `find_by!` (never Omnibus, no `fund_lead_entity_id` needed — nova branch). Increase-GHB opens the sub-account SYNCHRONOUSLY at create even though the fund is unverified (KYC is async); Piermont-Direct would BLOCK (verify-first gate). Treasury FBO create support (owner_type=fbo + beneficiary_name) is merged/live in treasury. Program strings: `'Increase (Grasshopper Bank)'`, `'Grasshopper Bank Main'`, `'Piermont Bank Standard Deposits Direct'`.

**Known non-crash-safe window** (engbot, not script): treasury CA created OUTSIDE the Nova EFA/VBA `$transaction`. If STEP 2 fails after "Treasury FBO Customer Account: <id>" prints, a plain re-run is refused by the dup-guard → manual reconciliation (delete orphan CA or hand-create EFA/VBA). Dry-run includes a read-only treasury CA precheck to warn of a pre-existing CA.
