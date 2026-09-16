---
name: bank-1667-pr9007-state
description: "BANK-1667 nova PR #9007 execution state — finalize-guard (option C) shipped + rebased onto main; MERGEABLE, signed, awaiting human review. Do NOT merge without Kevin."
metadata: 
  node_type: memory
  type: project
  originSessionId: 912df07d-6235-484e-99a4-4be3d3d4d9d8
  modified: 2026-08-05T23:21:56.059Z
---

nova PR **angellist/nova#9007** (branch `kevinliang/bank-1667`), enhancing the `onboardVehicleAccounts` engbot (fund identity + roles + KYC finalize + FBO account). Work done 2026-08-05:

**Option C — finalize guard (Kevin-approved).** `graph/engbot/onboardVehicleAccounts.ts` now guards the async `finalizeEntity` call: skip if `entityStatus.kycVerified || entityStatus.alloyApplication != null` (read via `clients.ipseity.getEntity`). Purpose: a partial-failure re-run (finalize succeeded → `createCustomerAccount` failed) must not re-submit KYC (finalize is a non-idempotent KYC/AML submit). Predicate is sound because **Kevin confirmed fund vehicles are always `verify_on_alloy=true`**, so `alloyApplication` is populated at finalize and covers the async-pending window (before `kycVerified` flips). NOTE: the client camelCases the ipseity response — fields are `kycVerified`/`alloyApplication`, NOT the snake_case schema names.

**Rebased onto current main** (was 130 behind). Reconciled with merged refactors: #9298 "make OnboardVehicleAccounts more ergonomic" (`vehicleEntityId` decodes in-schema via `uuids.veh.decode`, callers pass raw `veh_…`; import `uuids` from `lib/ids`) and #8874 (testModel arg). Kept both `uuids` + `entityTypeSchemaZod` imports; main's shell-identity path fully superseded.

**Known limitation (documented in PR body, NOT a defect):** tail-(i) — if `createCustomerAccount` succeeds but the EFA/VBA `$transaction` fails, the treasury account is orphaned and the dup-guard blocks re-run recovery (needs manual reconciliation). Full resumability = option D, deliberately scoped out.

**State as of last push (`173b3fd72b`, signed/verified):** MERGEABLE, CI re-running, `REVIEW_REQUIRED` (needs a human approval). **Do NOT merge without Kevin's explicit go-ahead.**

Also relevant: two live onboarding tasks NOVA-3732 (AngelList EI, LLC) + NOVA-3733 (Thursday Ventures 1X Holdings 4 LLC) are what this script would service; gap analysis established the only true code-blockers are "vehicle must already exist as Nova type `fund`" — everything else is manual-lookup inputs. See [[onboard-vehicle-accounts-spike]].
