---
name: schema-json-rake-not-make-graphql
description: "Treasury schema.json must be regenerated with rake graphql:schema:dump (CI's method), not make graphql"
metadata: 
  node_type: memory
  type: reference
  originSessionId: 5a12ef8b-3dac-4ce5-88fb-46c52582a13a
  modified: 2026-08-26T18:51:58.745Z
---

Treasury CI's `bin/ci/ensure_server_in_sync` regenerates `schema.graphql` + `schema.json` with **`bundle exec rake graphql:schema:dump`** then byte-compares (`cmp -s`). `make graphql` (bun `graphql:export:server`) orders `schema.json` input/output fields DIFFERENTLY (e.g. appends a new mutation arg last instead of alphabetically), so a schema.json produced by `make graphql` will FAIL the CI `cmp` even though schema.graphql matches.

**Always regenerate schema.json via `docker compose exec -T app bundle exec rake graphql:schema:dump`** after GraphQL changes, not `make graphql`. To verify CI will pass: `mv schema.json /tmp/s; bundle exec rake graphql:schema:dump; cmp -s /tmp/s schema.json && echo OK; mv /tmp/s schema.json` (restore after). Hit on [[bank1793-jpm-decouple]].
