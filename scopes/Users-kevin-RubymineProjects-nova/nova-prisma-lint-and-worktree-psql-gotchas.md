---
name: nova-prisma-lint-and-worktree-psql-gotchas
description: "nova CI has a lint-prisma step the graph test filter misses; prisma-lint enforces camelCase→snake_case @map word boundaries; `just dev psql <db>` ignores its db arg."
metadata: 
  node_type: memory
  type: reference
  originSessionId: 18177271-aaa5-4d7c-b954-10e8e6db65a0
  modified: 2026-09-08T06:52:05.729Z
---

Two nova worktree/CI-verify gotchas that cost a CI round on PR #9872.

**1. `lint-prisma` is a separate CI step your test filter never runs.** CI (`.buildkite/pipeline.rb`) runs `pnpm lint:prisma` (= `packages/prisma/scripts/lint-prisma.sh`, the `prisma-lint` tool). A local `just tt graph <filter>` / tsc / biome run does NOT cover it. The rule `field-name-mapping-snake-case` derives the expected `@map` from the field's camelCase **word boundaries**: `preSelectStatus` must map to `pre_select_status` (not `preselect_status`), `preSelectMatchedIpseityEntityId` → `pre_select_matched_ipseity_entity_id`. Always run `cd packages/prisma && pnpm lint:prisma` before pushing a `.prisma` model change. Fixing a bad `@map` on an unmerged migration: edit model + migration SQL, then `RENAME COLUMN` on the local dev+test DBs, `pnpm codegen && pnpm build` in packages/prisma. No app/graph code changes — the Prisma *field* name is unchanged, only the DB column.

**2. `just dev psql <dbname>` ignores the db arg and stays on `nova_pixel`.** It also word-splits a `-c 'SQL'` AND connects `-c` to the wrong (default) DB — `-c` is unusable here; use a `\c <db>` heredoc instead. To target the test DB (`nova_pixel_test` = `${POSTGRES_URL}_test`, per `graph/vitest.config.ts`), pipe `\c nova_pixel_test` then the SQL via stdin: `printf '%s\n' '\c nova_pixel_test' 'ALTER ...' | just dev psql`. Verify with `SELECT current_database()` — I once "confirmed" columns on `nova_pixel` while the graph tests (which use `nova_pixel_test`) still failed on the missing column. The graph test DB needs migrations/columns applied separately from the dev DB.

**2b. Reconnect race: the FIRST query right after `\c` intermittently returns empty output.** In a `\c <db>` heredoc, the first SELECT after the connect sometimes prints nothing (the query runs before the new connection settles) — I re-ran identical queries and got empty then rows. Put a throwaway `SELECT 1;` immediately after `\c <db>` to absorb the race, then your real queries. Don't conclude "0 rows" from a single empty result — retry.

See [[nova-worktree-lightweight-verify]], [[nova-matchmaking-local-e2e]].
