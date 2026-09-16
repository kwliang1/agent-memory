---
name: reference_bare_worktree_bringup
description: "How to make a bare/unprovisioned nova git worktree runnable (deps, env, test DB)"
metadata: 
  node_type: memory
  type: reference
  originSessionId: b0b27e7e-d16a-481c-927e-ecc3d5c083aa
  modified: 2026-08-05T07:26:11.365Z
---

A spawned nova git worktree may be **bare** — created with `git worktree add`, not `just worktree-init`, so it has no `node_modules`, no `.npmrc`, no `.devcontainer/.env`, and no dedicated DB container. Symptoms: `pnpm`/`vitest`/`turbo` missing, `@angellist/*` 401s, tests hit `undefined_test`.

Bring-up (all commands from the worktree root):
1. `cp <main-checkout>/.npmrc .npmrc` and `cp <main-checkout>/.devcontainer/.env .devcontainer/.env` (both gitignored). Main checkout is typically `/Users/kevin/RubymineProjects/nova`.
2. `pnpm install` — fast (~20s) because the pnpm global store is shared across worktrees (hardlinks).
3. `just codegen && just build` — required or graph tests fail resolving unbuilt workspace dists (e.g. `@angellist/sdk-venture`). ~1.5min + ~3.5min.
4. Tests use `${POSTGRES_URL}_test`. The `.env` `POSTGRES_URL` interpolates BOTH `${POSTGRES_PASSWORD}` and `${POSTGRES_PORT}` — substitute both when building a URL by hand.
5. If the shared `<...>_test` DB is behind main's migrations (e.g. `column X does not exist`, or a check-constraint violation from stale rows), reset it: from `packages/prisma`, `POSTGRES_URL=<base>_test npx prisma migrate reset --force --skip-seed` (`--skip-seed` avoids the Venture-monolith seed dependency). NOTE: that test DB is shared with the main worktree — resetting it disrupts a concurrent test run there.

Also: a stale local `main` ref (branch based on `origin/main` while local `main` is many commits behind) makes `gt submit` miscompute the branch as all the intervening commits. Use `gh pr create --base main` instead — it diffs against `origin/main` correctly. Commits still sign fine via 1Password (`op-ssh-sign`); local `%G? N` is only missing `gpg.ssh.allowedSignersFile`, GitHub still shows Verified. See [[feedback_worktree_paths]].

## Running the local app + screenshots (worktree-init flow)
- `just worktree-init -n <name>` creates a proper isolated worktree at `<mainrepo>/.worktrees/<name>` — dedicated docker containers, namespaced ports, and it CLONES the main dev DB (`nova` @ its port) via pg_dump|pg_restore into `nova_<name>`. It branches CODE from the main repo's HEAD (`-b <name> -- HEAD`); it canNOT check out an existing branch. To run an existing PR branch: after init, `cd` in and `git reset --hard origin/<branch>`, then `pnpm install` (frozen install used the stale lockfile) + `just codegen`, then `just dev up`. Migrate the DB forward first (on the SHARED dev `nova`, before init clones it) so the clone matches current-schema code.
- `just dev up` is long-running; poll `http://localhost:$PROCESS_COMPOSE_PORT/processes` (port in `.devcontainer/.env.worktree`) for each service `is_ready`. App on `NOVA_APP_PORT`, served properly at `https://portal-<name>.angellist.dev` (nginx). Teardown: `just worktree-teardown <name> --remove`.
- **Headless auth is blocked from the agent sandbox**: `just dev up` authenticates the `_angellist_v2` user session against the REAL external `angellist.dev` SSO (`AUTH_BASE_URL`/`VENTURE_BASE_URL` in `.env`), which returns **502 from the sandbox**. There is no local JWK/dev bypass — the graph resolves the user by calling AngelList (`graph/src/lib/auth/angellist.ts`, `graph/src/internal/context.ts`). Playwright/chromium ARE installed (run from `nova-e2e/tests` so `@playwright/test` resolves) and work — you just can't get past SSO. The dev-user cookie is `_angellist_v2` = `$e2e-auth|<angellist_id>|email="..."` (unsigned; format in `nova-e2e/services/emulator/lib/AuthCookie.ts`), but `just dev up` does NOT run the emulator so it's ignored. The OFFLINE-auth path is the nova-e2e **emulator** (`nova-e2e/services/emulator`, mocks `angellist.dev`): run it and point the app's `VENTURE_BASE_URL`/`AUTH_BASE_URL` at it, then the `$e2e-auth` cookie works. Simplest handoff when a live screenshot is needed: give the user the `portal-<name>.angellist.dev` URL + navigation and let them auth in their own browser.

## `just worktree-init` can fail outright when the fleet is large

From inside an existing `.worktrees/<name>` dir, bare `just worktree-init` (no flags) is the
documented "re-run infra setup here" mode — but it can die with
`could not find a collision-free port offset after 50 attempts`. `scripts/worktree/ports.sh`
searches offsets 100–599 from a `cksum` seed for 50 tries, and reserves every port already in a
sibling's `.env.worktree`, every docker-published port, AND **every listening port on the host**.
With ~40 worktrees on disk that space is exhausted. Nothing is wrong with the worktree.

Fallback that works and needs no ports or containers — the convention other sessions already use
(`nova_fern_test`, `nova_haze_test` all live on main's postgres):
1. copy `.npmrc`, `.devcontainer/.env`(+`.env.extend`), `app/.env`, `.devcontainer/secrets/` from the main checkout
2. append to the copied `.devcontainer/.env` a dedicated DB on **main's** postgres (port 7542):
   `POSTGRES_URL=postgresql://nova:${POSTGRES_PASSWORD}@localhost:7542/nova_<name>`
3. `CREATE DATABASE nova_<name>_test`, then from `packages/prisma`
   `POSTGRES_URL=<...>/nova_<name>_test npx prisma migrate deploy`
4. `pnpm install --frozen-lockfile`, `just codegen`, `just build`

This gives DB isolation without a container, and leaves the shared `nova_test` alone. `just` reads
only `.devcontainer/.env` (`set dotenv-path` at justfile:1), so the appended override is enough.

Also: `pnpm run lint:types` in `graph/` OOMs at the default heap (exit **137**, a V8 OOM stack — it
does NOT print a type error). Use `NODE_OPTIONS=--max-old-space-size=8192 pnpm run lint:types`.
