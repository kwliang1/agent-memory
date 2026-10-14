---
name: nova-worktree-init-port-collision-and-test-db
description: "`just worktree-init` can die with 'could not find a collision-free port offset after 50 attempts'; retry under a different -n name. A fresh worktree has no <db>_test DB; create it and `prisma migrate deploy`. Branch base is the stale local main."
metadata:
  type: reference
---

Three traps in a fresh nova worktree (2026-10-14, BANK-2287):

- **Port offset collision.** `scripts/worktree/ports.sh` seeds the offset from `cksum` of the name
  and tries only 50 consecutive offsets against every port already reserved by `.worktrees/*`,
  docker and `lsof`. With ~30 live worktrees the seed can land in a fully-booked range. Just rerun
  with a different `-n` (e.g. `fern2287` worked after `bank-2287` failed); same `-b` branch.
- **Branch base is local `main`**, which is usually hundreds of commits stale. `git reset --hard
  origin/main` right after init, then `pnpm install --frozen-lockfile`, `pnpm turbo build
  --filter='./packages/**'` (note `**`: `packages/sdk/*` is nested), then `just codegen` and
  `pnpm -C graph test:codegen`. Without the test:codegen step `lint:types` fails on
  `test/types/gen/graphql` Document exports.
- **No test DB.** vitest targets `${POSTGRES_URL}_test`, which init never creates:
  `docker exec nova-<name>-postgres-1 psql -U nova -d postgres -p <port> -c 'CREATE DATABASE
  nova_<name>_test'` then from `packages/prisma`: `POSTGRES_URL=postgresql://nova:$POSTGRES_PASSWORD@localhost:<port>/nova_<name>_test npx prisma migrate deploy`
  (source `.devcontainer/.env` for the password).

Also: husky hooks are absent in the worktree, so commit with `git -c core.hooksPath=/dev/null`
([[husky-hooks-fail-in-fresh-worktree]]); and `gt submit` on the stale trunk mis-titles, so push
with `git push -u origin <branch>` + `gh pr create` ([[gt-submit-stale-trunk-wrong-pr-title]]).
Related: [[nova-use-worktree-dev-skill]], [[nova-prod-db-access-from-bridge]].
