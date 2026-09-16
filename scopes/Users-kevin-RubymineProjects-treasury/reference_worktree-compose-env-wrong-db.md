---
name: worktree-compose-env-wrong-db
description: "Direct docker compose in a treasury worktree defaults TREASURY_WORKTREE_NAME=worktree and hits the wrong DB"
metadata:
  type: reference
---

In a treasury worktree, `TREASURY_WORKTREE_NAME` is set by the **Makefile** (`Makefile:8-9`, derived from the directory name and `export`ed). Invoking `docker compose -f docker-compose.yml -f docker-compose.worktree.yml ...` **directly** skips that, so `docker-compose.worktree.yml` falls back to its defaults: `container_name: treasury-worktree` and `TREASURY_DB_SUFFIX: _worktree`.

Consequence: specs, `rails runner`, and `rake db:migrate` run against `treasury_{development,test}_worktree` — a database **shared with every other worktree** doing the same thing — not `_<name>`. Symptom that gave it away: `make migrate` reported success while a later `db:seed` still said the migration was pending.

Always `export TREASURY_WORKTREE_NAME=<name>` before any direct compose call, or go through `make`. See [[worktree-never-raw-docker-compose]], [[worktree-ssr-auth-gap]].
