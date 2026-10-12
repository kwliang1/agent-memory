---
name: nova-worktree-env-points-at-shared-nova-db
description: "A nova worktree's .devcontainer/.env can point POSTGRES_URL at the SHARED `nova` DB instead of its own `nova_<name>`; symptom is a missing-table error from a resolver after auth already succeeded"
metadata:
  node_type: memory
  type: project
  originSessionId: cad04713-b516-48b4-a6e6-ac9ad1031ca5
  modified: 2026-09-29T19:12:00.105Z
---

**Check `grep -n POSTGRES_URL .devcontainer/.env` before debugging any "table does not exist" in a
worktree.** Measured 2026-09-29 in worktree `nova-bolt`: line 4 read
`…@localhost:${POSTGRES_PORT}/nova` — the **shared main-checkout DB** — while the worktree's own
migrated DB was `nova_bolt`. Both live on the same postgres container, so nothing looks wrong.

The tell is the *shape* of the failure: authorization succeeds and you land inside the resolver, then
Prisma throws `The table public.entity_matchmaking_upload does not exist`. Auth working while a table is
missing means you are on the wrong database, not mis-authenticated.

Compare the two before switching:
```
select count(*) from information_schema.tables where table_schema='public';
select count(*) filter (where finished_at is not null),
       count(*) filter (where finished_at is null and rolled_back_at is null),
       max(migration_name) from _prisma_migrations;
```
`nova` was 153 tables / 345 applied / **1 failed** — still the P3009
`20260806065302_require_entity_financial_account_id_on_distributions` from
[[nova-local-e2e-matchmaking]] — and had no `entity_matchmaking_*` tables at all. `nova_bolt` was 161 /
393 / 0. Point the env at the worktree DB rather than migrating the shared one; migrating `nova` would
disturb the main checkout.

A **targeted** process-compose restart does pick up the edited dotenv — `POST
localhost:$PROCESS_COMPOSE_PORT/process/restart/{graph,graph-worker,app}` was enough, no full-stack
bounce, because `just` re-reads the dotenv per invocation.

**Companion trap: the venture monolith may be running out of a *worktree*.** `bin/rails runner` from
`/Users/kevin/RubymineProjects/venture` died on an unchecked-out git gem (`document-service … is not yet
checked out`) while the server on :3001 was perfectly healthy — because the live server was
`.worktrees/venture-plaid-demo`. Find it with `ps auxww | grep '[r]uby'` (it is
`falcon host <path>/config/falcon.rb`); it does **not** appear in `docker ps`, and `lsof` is blocked
under the agent sandbox so `curl` is the only reliable port probe. Run session-minting scripts from
whichever checkout is actually serving.

See [[nova-local-e2e-matchmaking]], [[nova-worktree-dev-gotchas]].
