---
name: graph-tests-share-one-db-across-4-forks
description: graph vitest runs 4 forks against ONE test DB — adding a test file can fail an unrelated sibling; how to bisect it and tell it from real failures
metadata: 
  node_type: memory
  type: reference
  originSessionId: af366db7-dedb-49ab-a556-1a80afef428d
  modified: 2026-09-19T01:11:55.032Z
---

`graph/vitest.config.ts` sets `pool: 'forks'` with `maxForks: 4`, and every fork points at
the same `${POSTGRES_URL}_test`. Test **files** therefore run concurrently against one
database, and sibling suites share hardcoded fixture ids.

Observed 2026-09-18 (BANK-2120 PR 2), three data points on a *freshly created* DB:

1. new colocated service test present, calling `createAccount()` → `selectCandidate.test.ts >
   a re-pick after a bounced commit…` fails with `FAILED` instead of `COMMITTED`
2. same file moved aside → 336/336 pass
3. same file present but rewritten to touch no DB → 346/346 pass

Proximate cause (traced independently by a reviewer): a leftover entity with
`al_ipseity_entity_id='ent_inc'` and its `entity_financial_account`. `executePort` re-finds
the entity, the EFA upsert keys on `(entityId, treasuryAccountId)`
(`data/entity/financialAccount.ts`), the test's `treasuryAccountId` is a fresh `randomUUID()`
each run, so it takes CREATE and collides on `entity_financial_account_handle_key`.

**Do not over-claim the chain.** (3) shows the DB writes mattered, not just file count, but
the link from an Account insert to an `ent_inc` collision was never proven. Treat the
mechanism as unknown; the bisect below is the durable part.

**The concrete collision:** `entity.al_ipseity_entity_id` is UNIQUE
(`entity_al_ipseity_entity_id_key`) and matchmaking suites share hardcoded fixture ids such
as `ent_inc`. A full `src/services/entityMatchmaking` run leaves that entity behind, so the
**next** run of the same suite reads red at `selectCandidate.test.ts` even with no code
change. Recreate the DB before any full-suite run you intend to trust.

**Bisect:** move the suspect file aside (`mv x.test.ts /tmp/`) and rerun on a freshly
recreated DB. That isolates it in one run, unlike toggling code.

**Telling the three DB failure modes apart:**
- fails alone too → real defect, or migrations behind
- passes alone, fails in suite, **reused** DB → accumulation; recreate the DB
  (see [[nova-tests-self-poison-warm-db]])
- passes alone, fails in suite, **fresh** DB → this

**Fix:** prefer a DB-free unit test — split the pure logic out of the service and test that,
leaving the thin prisma wrapper untested like the rest of `data/`. Reach for a factory only
when the behaviour under test *is* the persistence.

Recreate with `DROP DATABASE`/`CREATE DATABASE` + `prisma migrate deploy` from
`packages/prisma` (~1 min), or `CREATE DATABASE x TEMPLATE nova_test`.

Related: [[nova-tests-self-poison-warm-db]], [[negative-check-toggles-use-edit]].
