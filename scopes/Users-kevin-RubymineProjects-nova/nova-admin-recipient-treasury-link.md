---
name: nova-admin-recipient-treasury-link
description: "nova PR #9417 — admin-only Treasury Account deep-link chip on the distribution recipient blade (On-Nova gated), open for review, not merged"
metadata: 
  node_type: memory
  type: project
  originSessionId: 285a7fe8-0cef-43b9-b58d-e13620a32d31
  modified: 2026-08-12T00:36:01.791Z
---

nova PR **#9417** (branch `kevinliang/nova-admin-recipient-treasury-link`, off origin/main, signed, OPEN + MERGEABLE, **NOT merged**, awaiting Kevin's review). Buildkite #45812 was running at hand-off.

**What:** admin-only "Treasury Account (xxxx…yyyy)" row on the distribution-pipeline **recipient blade** (`app/src/components/views/Distribution/PipelineTab/DistributionPaymentBlade/index.tsx`) deep-linking to the treasury CustomerAccount portal — the recipient-blade analogue of the vehicle-account chip.

**Reused, made shared:** `TreasuryCustomerAccountAdminLinks` now lives at `app/src/components/core/Admin/TreasuryCustomerAccountAdminLinks.tsx` (moved from under the EFA view per Kevin's "make it shared" ask — git rename; both importers + vehicle test mock repointed), wrapping `AdminActions`. Gave `AdminActions` a new `placement='floating'|'inline'` prop (floating = unchanged default for its 2 existing callers; **inline** required because the floating fixed chip at zIndex 2 renders BEHIND the ADAPT Blade portal (~z1200+) → invisible; ADAPT z-scale = 0/1/2/900/1000/1100/1200/1300/1e6). Inline row sits under the On-Nova badge in the blade `description`, `display='inline-block' alignSelf='flex-start' paddingX='50' paddingY='25'`, `accent10` brand token (yellow on Capital Factory, indigo on asuna — same token as vehicle chip; Kevin confirmed keep it brand-adaptive).

**Gating:** admin AND On-Nova. New backend field `DirectoryEntity.treasuryCustomerAccountIds` (`graph/src/internal/models/directory/directoryEntity/directoryEntity.ts`); resolver body extracted to `treasuryCustomerAccountIds.ts` (`resolveTreasuryCustomerAccountIds`, unit-testable) — returns `[]` unless `angelListUser?.isAdmin || trueAngelListUser?.isAdmin` (byte-identical to the vehicle `EntityFinancialAccount.treasuryCustomerAccountIds` field). Resolved via a **batched DataLoader** `treasuryCustomerAccountIdsByEntityId` (`graph/src/internal/loaders/virtualBankAccount.ts`) keyed on `connectedEntityId` — avoids one VBA query per pipeline row (the field is on the `DistributionPaymentBlade_Payment` fragment spread over every row). Semantics are **entity-level** (all of the connected entity's on-network treasury CustomerAccounts), by design: matches the On-Nova signal granularity + works at all payment stages (a payment-specific settlement VBA only exists post-routing). `length>0` ⟺ `isOnNetwork` (both derive from the connected entity's VBAs).

**Gate passed:** 3 review rounds, 2 successive clean, + an adversarial-critic round. Round 1 caught the z-index occlusion + the N+1 → both fixed. Adversarial critic's valid catch = no graph-layer test → added DB-free graph tests (gate: non-admin/no-connected-entity → [] w/ loader untouched, angelListUser & trueAngelListUser admin → loads; loader: batch-into-one-query, input-order mapping, dedup). Type-check 32/32, Biome clean, blade suite green, 3 FE tests (`treasuryAdminChip.test.tsx`) + 6 graph tests.

Built/verified on worktree `recipient-treasury-link` (app `portal-recipient-treasury-l.angellist.dev`, graph :4550). Repro route: `/asuna/distributions/dist_RECON001/pipeline` → Pipeline → On-Nova recipient (Horizon Wire Partners / Meridian Wire Fund II / Pinnacle ACH Capital / Summit ACH Ventures). Needed a local seed backfill first — see [[nova-worktree-dev-gotchas]] (NULL `entity_financial_account_id`).
