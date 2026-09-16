---
name: spawned-nova-worktree-is-bare
description: "Spawned nova build sessions land in a bare, stale, unprovisioned worktree — must run just worktree-init before anything compiles."
metadata: 
  node_type: memory
  type: project
  originSessionId: a84d0338-5fe1-4dc5-8053-78cf4a876a3e
  modified: 2026-09-02T23:01:21.953Z
---

When a session is spawned onto a nova worktree (e.g. `/Users/kevin/RubymineProjects/.worktrees/<name>`), it is **not** the `just worktree-init` env — it's a bare git worktree, often on a stale branch (`wt/<name>`) hundreds/thousands of commits behind `origin/main`, with **no** `node_modules`, `.npmrc`, `.devcontainer/.env`, generated artifacts, or docker/DB. Nothing (`tsc`, `biome`, `just tt`) runs until it's provisioned.

**Fix (what actually worked for BANK-1667):**
1. Re-base onto current `origin/main` (`git fetch`; branch off `origin/main`, not the stale `wt/*`).
2. The repo pins an exact node in `.tool-versions` (e.g. `20.17.0`) that asdf often does **not** have installed → `asdf install nodejs <version>` first, else `pnpm install` dies with "No version is set for command node" (exit 126).
3. Provision via `just worktree-init -n <name> -b <branch>` from a location whose HEAD is the correct base (`repo_root` = first `git worktree list` entry = the main checkout; new worktree lands at `<main>/.worktrees/<name>`, branch created from CWD HEAD via `-b ... -- HEAD`). `-b` **creates** a branch, so free/delete the name first if it exists. Move in-flight work via `git stash` (shared across worktrees of the same repo) then pop.
4. worktree-init's `pnpm install` + `prisma generate` is **not** enough for a green graph `tsc` — it leaves nested workspace pkgs unbuilt, so `tsc` shows spurious `TS2307: Cannot find module '@angellist/nova-*'` in unrelated files. Run `pnpm -r build` (all packages) so `@angellist/nova-*` resolve. Judge your diff by whether *your* files have errors, not the global count.

biome needs `node_modules` too (resolves `@angellist/biome-config`), so it's blocked until install as well. See [[bridge-is-slack]] for how Kevin is reached during these sessions.

**Faster in-place provisioning that actually worked (NOVA-3569, 2026-08-03):** you do NOT have to create a fresh worktree — provision the spawned dir in place.
1. From inside the spawned worktree, `git checkout -b kevinliang/<branch> origin/main` (after `git fetch origin main`). Node `20.17.0` was already installed via asdf; check `asdf list nodejs` before assuming you must install.
2. `just worktree-init` with **no args** = infra-only mode (decrypts env, copies `.npmrc`/`.devcontainer/.env`/secrets, docker, DB, ports, `pnpm install`, `prisma generate`) for the current worktree. BUT it hard-derives `WORKTREE_PATH="${REPO_ROOT}/.worktrees/${NAME}"` where `REPO_ROOT` = main checkout (`/Users/kevin/RubymineProjects/nova`), while the spawned dir lives at `/Users/kevin/RubymineProjects/.worktrees/<name>` — a DIFFERENT path — so it fails copying `.devcontainer/.env`. Bridge the two with a symlink first: `ln -sfn /Users/kevin/RubymineProjects/.worktrees/<name> /Users/kevin/RubymineProjects/nova/.worktrees/<name>`, then re-run `just worktree-init`. All cp/docker/db ops then act on the real worktree through the symlink. Still run `pnpm -r build` after (step 4 above).
3. Nothing migrates the `${db}_test` DB (vitest points at `${POSTGRES_URL}_test`). Create+migrate it once: `psql "$POSTGRES_URL" -c "CREATE DATABASE <db>_test"` then `POSTGRES_URL="${POSTGRES_URL}_test" pnpm -C packages/prisma exec prisma migrate deploy`.
4. Run graph tests/tsc directly, NOT through turbo (`just tt` hits the hanabi/dist turbo pitfalls): `set -a; source .devcontainer/.env; set +a` then `pnpm -C graph test <file>` / `pnpm -C graph lint:types` / `pnpm -C graph exec biome check`. Sourcing `.env` is required — running pnpm directly otherwise dies with "Invalid URL" in `packages/authz` (unset datasource env).

**Build filter must be `./packages/**`, not `./packages/*` (BANK-1924, 2026-09-02):** the single-star filter skips nested workspaces (`packages/sdk/venture` → `@angellist/sdk-venture`, `packages/vulcan/schema` → `@angellist/nova-vulcan-schema`), and vitest then fails EVERY suite in a dir with "Failed to resolve entry for package" while the 6 pure-unit suites pass. `pnpm -r --filter './packages/**' build` (~2 min) fixed it. Also: Bash cwd persists across calls in this harness — always use absolute paths, or a `cd graph` in one call breaks `source .devcontainer/.env` in the next.

**Stack-free path when `just worktree-init` can't allocate ports (BANK-1923, 2026-09-02):** with ~20 live worktrees + ~120 host listeners, `scripts/worktree/ports.sh` dies with "could not find a collision-free port offset after 50 attempts". For backend-only work you don't need the stack at all:
1. `cp nova/.npmrc <wt>/.npmrc`; `sed 's#/nova$#/nova_<name>#'` main's `.devcontainer/.env` into `<wt>/.devcontainer/.env` (so vitest hits `nova_<name>_test` on MAIN's postgres, port 7542 — never main's `nova_test`).
2. Do NOT clone from `TEMPLATE nova_test` — main's `nova_test` was schema-drifted (a migration failed 42701 on replay). `CREATE DATABASE nova_<name>_test` empty, then `POSTGRES_URL=...nova_<name>_test pnpm -C packages/prisma exec prisma migrate deploy` from zero (~1 min). Factories need no seed.
3. `pnpm install --frozen-lockfile` → `pnpm -C packages/prisma codegen` (prisma generate MUST precede the package build or `@angellist/nova-prisma` tsc fails on `./gen/client`) → `pnpm -r --filter './packages/**' build`.
4. graph vitest also needs `pnpm -C graph codegen` (proto stubs, else `proto/gen/services/PDFOps_connect` missing) and `pnpm -C capital-api codegen && pnpm -C capital-api schema:dump && pnpm -C graph schema:dump && pnpm -C graph test:codegen` (else `test/types/gen/graphql/graphql` missing; capital-api's codegen ran fine without a capital DB).
5. Running 3+ FSM-heavy suites in one vitest invocation on this shared postgres produced spurious 15s timeouts that vanish when run alone or as a whole-dir run — re-run before believing a timeout.

**Two more gotchas (BANK-1941, 2026-09-01):**
- `graph` tsc OOMs node's default heap (native stack-trace crash mid-`lint:types`). Run with `NODE_OPTIONS=--max-old-space-size=12288`. **Not `app` tsc** — measured 2026-09-10, `pnpm -C app lint:types` peaks at **1.95 GB** and passes on the default heap. Don't set a 12 GB ceiling for it: this machine already swaps (9.4M pageouts observed), and a needless ceiling lets one process page instead of collecting.
- `graph test:codegen` scans `node_modules/@angellist/capital-api` test documents against the capital proxy schema; in a fresh worktree capital-api's gitignored codegen is stale/missing, so graph's test:codegen fails on secondaries documents that look unrelated. Fix: `pnpm -C capital-api codegen && pnpm -C capital-api schema:dump` (needs the `capital_<name>` DB worktree-init created), then re-run `pnpm -C graph schema:dump && pnpm -C graph test:codegen`. `pnpm -r build` also fails at capital-api for the same reason — build `--filter './packages/*'` instead.
