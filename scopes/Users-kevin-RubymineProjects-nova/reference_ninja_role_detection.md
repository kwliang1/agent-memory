---
name: reference_ninja_role_detection
description: "Detecting the Ninja anonymity role: use permissive rolesSchema, not the enum schema (which silently drops the whole set)"
metadata: 
  node_type: memory
  type: reference
  originSessionId: dbe18dd9-d97a-4b2d-8bae-4a371dd6b84a
  modified: 2026-08-19T20:20:36.869Z
---

For anonymity/Ninja checks on `OrganizationMember.roles`, detect with the **permissive** `rolesSchema` (`z.string().array().default([]).catch([])`) from `@angellist/nova-core/roles`, NOT `organizationMemberRolesSchema` (`z.enum(...).array().catch([])`).

Why: the enum schema's array-level `.catch([])` discards the **entire** array if any single element fails enum validation — so one unknown/legacy sibling role silently yields `[]`, `wasNinja` reads false, and Ninja gets stripped. The permissive string-array schema keeps `'ninja'` regardless of unknown siblings. `entity.ts` authorizedSignatories already uses `rolesSchema` for this reason.

`Ninja` is a **provisioning-admin role**, not customer-invitable: set only on the hidden `ninjaAdminAccountId` (via `upsertNinja` + the Venture team-sync "ninja admin for requester"), always paired with `Admin`; only AL-admins can attach it to an invite. So invite-redemption strip paths (`createMember`) are effectively unreachable for a ninja.

Context: PR angellist/nova#7955 (NOVA-1124) — preserve Ninja across all member role-write paths. To make a data-layer `SELECT … FOR UPDATE` lock atomic regardless of caller, wrap lock+read+write in `ensurePrismaTransaction` (`lib/prisma.ts`) — it `$transaction`-wraps a full client and runs an existing tx client inline (the `Prisma.TransactionClient` type alone does NOT enforce a real tx; a full `PrismaClient` is structurally assignable). See [[reference_treasury_transfer_state_machine]] for adjacent banking-controls context.
