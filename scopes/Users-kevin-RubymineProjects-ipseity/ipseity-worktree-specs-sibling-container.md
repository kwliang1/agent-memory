---
name: ipseity-worktree-specs-sibling-container
description: Run ipseity specs from a worktree with a sibling docker container; .devcontainer/.env quotes break --env-file and specs need the temporal container up
metadata:
  type: reference
---

`ipseity-app-1` mounts the main checkout, so a worktree needs its own container:

```sh
sed -E "s/^([A-Z_0-9]+)='(.*)'$/\1=\2/" .devcontainer/.env > "$SCRATCH/ipseity.env"
docker start ipseity-temporal-1
docker run -d --name ipseity-app-wt --network ipseity --env-file "$SCRATCH/ipseity.env" \
  -v "$PWD":/app -v ipseity_app-gems:/usr/local/bundle -w /app ipseity-app sleep infinity
docker exec ipseity-app-wt bash -lc 'RAILS_ENV=test bundle exec rspec <paths>'
```

**Why:** `.devcontainer/.env` single-quotes its values (`TEMPORAL_HOST='temporal'`); docker `--env-file` keeps the quotes literally, so the `before(:suite)` Temporal connect fails with a DNS error on `'temporal'`. The quoted file works for compose only because compose strips them. `srb tc` and rubocop run in the same container.

**How to apply:** strip the quotes before `--env-file`, start `ipseity-temporal-1` (stock image, safe to share), and `docker rm -f ipseity-app-wt` when done.

The host recipe in the repo's CLAUDE.md (port 5438 env vars, no container) can't pass: `spec/support/temporal.rb` connects to `127.0.0.1:7233` in `before(:suite)`, and docker-compose publishes no Temporal port. Use this container instead.

All worktrees share one test database, and `db:test:prepare` reloads it from whichever worktree runs it. A sudden `PG::UndefinedTable` or pending-migration error is usually another worktree's schema, not your code: re-prepare before debugging. Related: [[feedback_ipseity_specs]], [[treasury-specs-sibling-container]].
