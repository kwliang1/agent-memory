---
name: treasury-schema-load-landmine
description: treasury CI does db:schema:load then db:migrate — a migration merged without its schema.rb dump becomes a landmine that detonates when a later PR bumps the schema version past it
metadata: 
  node_type: memory
  type: project
  originSessionId: f8489e21-121e-4185-b986-ed2da6f8d957
---

Treasury CI (`bin/ci/rspec`, `bin/ci/ensure_sorbet_in_sync`) sets up the DB with `db:create db:schema:load db:migrate`. `schema:load` calls `assume_migrated_upto_version`, marking every migration ≤ schema.rb's version as applied without running it.

**Why:** If PR A merges a migration but forgets the schema.rb dump, main stays green (migrate still runs it, since schema version < migration version). When PR B later bumps schema.rb's version past A's migration — dumped from a base without A — A's migration is silently skipped forever: missing table → Trilogy 1146 in rspec + tapioca DSL RBI drift in Sorbet job. Seen 2026-07-08: #8141 (create_dibs_rtp_metadata, no schema dump) + #8142 (Kevin's index migration, version 20260708190231) → build 31222 red.

**How to apply:** When diagnosing "PR CI green but main red" in treasury, check whether the schema.rb version exceeds a migration whose table/columns aren't in schema.rb (`git show origin/main:db/schema.rb | grep <table>`). Fix: regenerate schema.rb from a full migrate on latest main. Prevention: before merging, verify any PR adding a migration also updates db/schema.rb, and rebase+regenerate schema.rb if migrations landed on main since branching.
