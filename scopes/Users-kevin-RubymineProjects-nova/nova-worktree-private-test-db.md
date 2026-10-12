---
name: nova-worktree-private-test-db
description: "A worktree whose .env points at main's postgres shares a stale nova_test; clone a private test DB, and know that `just` clobbers a POSTGRES_URL override"
metadata:
  node_type: memory
  type: reference
  originSessionId: bd0b6a81-9d29-4aff-8a01-df0845ab0c07
  modified: 2026-10-01T07:06:23.921Z
---

A worktree brought up by copying main's `.devcontainer/.env` points `POSTGRES_URL` at main's postgres, so `just tt graph` hits the shared `nova_test`. On 2026-09-30 that DB was 3 migrations behind, which failed 17 unrelated distribution tests with P2022 missing column. Don't `migrate deploy` the shared DB, because other checkouts read it. Instead:

- `psql "$BASE/postgres" -c "CREATE DATABASE nova_<name>_test TEMPLATE nova_test"`, then `POSTGRES_URL=$BASE/nova_<name>_test npx prisma migrate deploy` from `packages/prisma`.
- The justfile sets `dotenv-override := true`, so `export POSTGRES_URL=...` before `just tt` gets silently overwritten. Run `pnpm run test <files>` inside `graph/` instead, with `.devcontainer/.env` sourced and `POSTGRES_URL=$BASE/nova_<name>` exported. vitest appends `_test`.

Related: [[nova-worktree-env-points-at-shared-nova-db]], [[reference_graph_tests_need_just]].
