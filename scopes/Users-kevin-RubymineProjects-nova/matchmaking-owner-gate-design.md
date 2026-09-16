---
name: matchmaking-owner-gate-design
description: "BANK-1941 final design: commit owner gate (NO_OWNER_ACCOUNT), owner_user_id CSV column, id-keyed shells only, force-sync/Temporal refuse ownerless ports; follow-ups BANK-1948/1950; venture identity facts."
metadata: 
  node_type: memory
  type: project
  originSessionId: 44520885-8e09-4322-aeb3-2c70d8ddc7fc
  modified: 2026-09-08T23:53:31.211Z
---

Shipped on PR #9830 (branch kevinliang/bank-1941; rebuilt 2026-09-08 by session bloom at head `a72d4c074c` after rebase + review-fix round), decided live with Kevin: **no headless entities, ever**.

**2026-09-08 additions (all at a72d4c074c):**
- Type/fn renamed: `CommitOwner`→`EntityOwner`, `canResolveCommitOwner`→`canResolveEntityOwner` (Kevin: "commit owner" reads as the acting admin).
- Gate + port now refuse/error when the id belongs to a SOFT-DELETED account (deletion = revocation; `softDelete` scrubs email to `al-deleted-account-<id>@angellist.com` but RETAINS angellistId), and when the email matches an active account with a DIFFERENT non-null angellistId (wrong-person guard). `findAccountByEmail` is active-only; `findOrCreateByAngellistId` email-first-finds (case-insensitive) before inserting so case-variant emails never split.
- `commitRowCore` normalizes blank owner fields (''→undefined) at entry — covers raw API callers all paths.
- `hashCommitContent` normalizes owners (email `normalizeEmail` from `lib/string`; uid via `parseOwnerUserId`) to match case-insensitive resolution — safe pre-merge because no shipped client passes owner fields on main (singular admin mutation accepts them but has no client document). `contentHash.test.ts` + `csv.test.ts` pin both fingerprints' pre-column back-compat.
- `POSTGRES_INT4_MAX` now exported from `graph/src/data/prisma/types.ts` (shared with admin/organization/list.ts).
- Adversarial test-redundancy review (3 rounds, clean close): deleted lifecycle case 38 + commitRow's plain re-commit test + '00' case; chunk suite collapsed to typed test.each tables; fixture extraction deferred to BANK-2005 (after #9871 lands).

- **Owner gate** in `commitRowCore` (`graph/src/services/entityMatchmaking/ownerResolution.ts`): a port that would CREATE an entity refuses with non-stranding outcome `NO_OWNER_ACCOUNT` — returned BEFORE the idempotency key binds — unless the owner resolves: account by `angellistId` → account by email (find-only) → id+email creates an **id-keyed shell** (`data/account.findOrCreateByAngellistId`, savepoint-guarded). Email-keyed shells are never created (`findOrCreateByEmail` deleted): a *secondary* venture email strands the grant — login reconciliation (`lib/auth/account.ts accountFromAngellist`) matches angellistId first, then PRIMARY email only. An entity nova already holds passes ownerless (wallet-ensure).
- **`owner_user_id`** CSV column (nova-core ingest parser) is the manual remediation: venture admin search → put the user id in the CSV. `parseOwnerUserId` accepts only [1, 2147483647] — `0` is the blank-cell artifact and an id-0 shell would pool grants unreconcilably.
- Force sync and the Temporal commit chunk carry no owner → they now REFUSE new-entity ports (force maps to NOT_APPLICABLE). [[BANK-1948]] (thread owners through force sync) is the enabler to restore force-porting; **BANK-1950** = auto-resolve email→canonical venture user at port time via a NEW venture Prophet route wrapping `User.find_by_any_email` (venture exposes NO user lookup today; nova rail is `graph/src/clients/venture/request.ts`, service 'angellist').
- Hash back-compat pattern: both fingerprints (server `contentHash.ts` `|uid:` suffix, client `csv.ts hashParsedRows` 5th tuple element) append ONLY when the new field is present, so pre-change hashes replay/dedup unchanged. Reuse this pattern for any future field.
- Venture identity facts: nova `Account.angellistId` is unique but can be STALE until the user's next login re-points it (observed live: venture@angellist.com held 16463621 until login re-set 16773456). `accounts/merge` requires angellistId on BOTH sides — a null-id shell is unmergeable. venture auth payload already carries `allEmails` (login-time reconciliation option, unused).

See [[matchmaking-pii-scoring-architecture]] and [[nova-local-e2e-matchmaking]].
