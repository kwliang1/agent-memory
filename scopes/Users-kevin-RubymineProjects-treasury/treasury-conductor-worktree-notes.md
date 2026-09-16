---
name: treasury-conductor-worktree-notes
description: "Treasury worktree notes salvaged from the conductor vancouver scope; its make graphql claim was wrong"
metadata:
  type: reference
---

**Correction first:** this file previously said `make graphql` must be run from the main worktree. Do not use `make graphql` at all — it orders schema.json fields differently and fails the CI `cmp`. Regenerate with `rake graphql:schema:dump`, which is what CI runs. See reference_schema-json-rake-not-make-graphql.


- Main repo is at `/Users/kevin/RubymineProjects/treasury` (has `main` checked out)
- Conductor workspace is at `/Users/kevin/conductor/workspaces/treasury/vancouver` (a git worktree)
- Cannot checkout `main` or any branch already used by the other worktree
- To free a branch for the main worktree, use `git checkout --detach HEAD`
- User uses `gt` (graphite) CLI tool for branch management

- Local dev: `.devcontainer/.env`
- Prod: `config/configtool/prod-us-west-2-zeus/internal.hcl` (secrets/config), `override.hcl` (service URL overrides)
- Staging: `config/configtool/staging-us-west-2-hermes/internal.hcl`, `override.hcl`
- Non-secret env vars like BASE_URLs go in `internal.hcl`, not `override.hcl`
- `override.hcl` is for values that override shared/base config (internal service URLs)

- Husky + lint-staged, but node_modules not installed in this workspace
- Use `--no-verify` for commits and pushes

- Run via Docker: `docker compose exec app bundle exec rspec`
- Docker container name "treasury" may conflict with other worktrees

- `make graphql` must be run from the main worktree (needs node_modules)
- When adding new GraphQL enum values (e.g., SERVICE_TYPES), codegen regenerates frontend types

Relocated 2026-09-16 from the conductor treasury-vancouver worktree scope, which no session loads.
