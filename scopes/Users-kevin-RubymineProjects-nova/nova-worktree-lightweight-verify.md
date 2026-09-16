---
name: nova-worktree-lightweight-verify
description: "Verify a nova graph#build tsc error + run pure unit tests in a plain worktree WITHOUT full just worktree-init (docker/DB/codegen)"
metadata: 
  node_type: memory
  type: reference
  originSessionId: 937ccaa4-caea-417e-88e1-fd7c3d662e28
  modified: 2026-08-28T19:01:02.409Z
---

To verify a nova `graph#build` (tsc) fix or run **pure** unit tests without the heavy `just worktree-init` (docker + DB + codegen), a plain `git worktree add` works:

1. Plain `git worktree add <path> <branch>` off the main nova checkout (shares git objects; branch not checked out elsewhere).
2. Copy the gitignored auth/env from the main checkout: `cp nova/.npmrc` and `cp nova/.devcontainer/.env` into the worktree. Then `pnpm install --no-frozen-lockfile` (frozen fails on an `autoInstallPeers` lockfile mismatch; warm store makes it ~20s).
3. `pnpm turbo build --filter='./packages/*'` — builds ALL workspace packages (`@angellist/nova-core`, `nova-logger`, `nova-prisma-extensions`, `sdk-venture`, …). No DB needed. This resolves the "Failed to resolve entry for package / Cannot find package … dist" vitest+tsc noise from unbuilt sibling `dist/`. `nova-prisma`'s build = `prisma generate` (no DB).
4. `npx tsc --noEmit` then **grep for the specific changed files** — a graph#build type error (e.g. `TS2345`) is self-contained to those files + `nova-core`. The thousands of remaining errors are graph's own codegen (`proto/gen/*`, `schema.graphql`, `test/types/gen`) which need `schema:dump`/`buf` (DB/env) — separable NOISE, not your fix. If your changed files show 0 errors and the target error is gone, the fix compiles; CI (with full codegen) confirmed green matching this prediction.
5. Pure unit tests (no DB/proto imports, e.g. `parseIngestRows.test.ts`) run via `npx vitest run <file>` once packages are built. Test files that transitively import `lib/prisma`/`lib/grpc` fail to LOAD with `Cannot find package 'proto/gen/...'` — environmental (missing graph codegen), NOT your bug; read them statically instead.
6. biome: use `/Users/kevin/.asdf/shims/biome check <files>` (NOT `npx biome` — resolves the wrong package; see [[treasury-worktree-dev-loop]] analog). `biome check --write` auto-wraps long imports.

Only commit your intended files — `.npmrc`/`.env` are gitignored (won't commit); don't sweep the lockfile. See [[bash-cwd-persists-across-calls]] / [[shared-checkout-worktree-isolation]] for worktree hygiene.

## Verification that lies (both bit me on 2026-09-01)

7. **`npx tsc --noEmit` in `graph/` OOMs in a worktree** — exit 134, "JS heap out of memory", ~80 lines of GC dump and **zero `error TS` lines**. So `npx tsc --noEmit 2>&1 | grep -c 'error TS'` prints `0` and reads as a clean project typecheck. It is a crash. Always capture the exit code (`echo "exit=$?"`) and rerun with `NODE_OPTIONS=--max-old-space-size=12288`. With enough heap graph reports ~392 errors in a plain worktree (308 × TS2307 on the missing `graph/src/types/gen` + `graph/test/types/gen`, rest an implicit-any cascade).
8. **Prove "my change adds no errors" against the base, don't assert it.** Everything is committed in a worktree, so `git checkout <base-sha>`, rerun tsc, compare counts, `git checkout <branch>`. 392 vs 392 is evidence; "0 errors" was not.
9. **Never `| tail -N` a lint/typecheck you are about to call green.** A `biome check` error scrolled off the top and I reported clean; husky then rejected the commit for a nested ternary (`lint/style/noNestedTernary` — AGENTS.md forbids them). Print the full output and the exit code.
10. `graph/.lintstagedrc.cjs` runs **only** `lint:format`. `packages/core` and `packages/prisma` run `lint:types` too. A green husky run is not a graph typecheck.

## Post-rebase verification is cheap — `schema:dump` needs no Postgres (2026-09-11)

11. **`pnpm schema:dump` in `graph/` runs fine in a worktree with no database.** AGENTS.md implies codegen needs a running Postgres via docker-compose; the *schema dump* does not — it builds the Pothos schema in-process (`tsx scripts/dump_schema.ts`) and writes `graph/schema.graphql`. Took seconds in `.worktrees/nova-pixel` with no containers up.

 This matters because `graph/schema.graphql` and `app/gen/` are gitignored, so **after rebasing onto a main that changed the GraphQL schema, app `tsc` fails in files you never touched.** Seen on nova PR #9989: 5 × `TS2339 Property 'DATA_MISMATCH' does not exist on type 'typeof DistributionDraftAlertCheck'` in `Distribution/PipelineTab/*` — enum values main's #10000 had added to `graph/src/internal/models/distribution/distributionDraftRowAlert.ts` but which were absent from my stale dump. Nothing was wrong with the branch; CI regenerates and was fine.

 **Recipe after any rebase that pulls graph schema changes:** `cd graph && pnpm schema:dump` → `cd ../app && pnpm codegen` → `npx tsc --noEmit`. Confirm the specific symbol landed in `schema.graphql` before believing the errors are yours. Don't reach for `just worktree-init`.

 Diagnostic tell: the failing files are ones your diff doesn't touch, and the missing symbol exists in `graph/src` but not in `graph/schema.graphql`.
