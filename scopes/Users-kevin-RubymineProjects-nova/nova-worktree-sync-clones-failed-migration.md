---
name: nova-worktree-sync-clones-failed-migration
description: "just dev sync clones a dev DB carrying a FAILED prisma migration; Prisma then refuses every later migration and sync still reports Completed — the worktree silently comes up ~14 migrations behind"
metadata:
  node_type: memory
  type: project
  originSessionId: ac78a74b-2faa-4731-aad4-1cab26e3e3d1
  modified: 2026-09-24T22:35:00.000Z
---

`just worktree-init` + `just dev up` clone a snapshot of the shared dev DB. That snapshot can
carry a **failed** row in `_prisma_migrations`. Prisma's P3009 then blocks every later migration,
and the `sync` process still lands on **Completed** — so the stack boots green against a schema
that is months behind.

Seen 2026-09-24 in worktree `mmdoc`: newest applied migration was 2026-08-05, ~14 pending, and
none of the 5 `entity_matchmaking_*` tables existed. Symptom in the UI was
*"Couldn't load the batch list"* — which reads like an auth or resolver problem, not a schema one.

Check after any worktree bring-up, before debugging anything else:
```
psql -h localhost -p <PG_PORT> -U nova -d nova_<name> -tAc \
  "select migration_name, finished_at from _prisma_migrations order by finished_at desc nulls last limit 3"
```

The blocker found here was `20260806065302_require_entity_financial_account_id_on_distributions`
(sets `distribution.entity_financial_account_id` NOT NULL); the snapshot had 8 null rows. Repair
the data, don't drop the constraint — each row's own `sender_entity_id` had a valid EFA:

```sql
UPDATE distribution d SET entity_financial_account_id =
  (SELECT efa.id FROM entity_financial_account efa WHERE efa.entity_id = d.sender_entity_id LIMIT 1)
WHERE d.entity_financial_account_id IS NULL;
```
then `npx prisma migrate resolve --rolled-back <name>` and `npx prisma migrate deploy`, from
`packages/prisma/` with `.devcontainer/.env` + `.env.worktree` sourced (**not** `just prisma`,
which is staging/prod-only and demands `-s`/`-p`). Restart graph + graph-worker afterwards.

Deleting matchmaking rows for a re-score needs the FSM children dropped first, all in ONE
transaction (each `psql -c` is its own tx, so a later FK error rolls back the earlier deletes):
`fsm_event_history` → `fsm_action_history` → `fsm_execution_history` → `fsm_event` →
`fsm_execution` → `entity_matchmaking_upload` → `entity_matchmaking_ingest_file`. Drop the
ingest_file row too, or `reserve` dedups on its content hash and reuses the old document.

See [[use-worktree-init-skill]], [[reference_bare_worktree_bringup]].
