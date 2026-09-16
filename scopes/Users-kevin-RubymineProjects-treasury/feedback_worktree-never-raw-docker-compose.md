---
name: worktree-never-raw-docker-compose
description: "In a treasury worktree, never run raw `docker compose -f docker-compose.yml -f docker-compose.worktree.yml up/run` — it collides with the shared `treasury` project and can kill shared mysql + sibling worktree app containers. Use make targets."
metadata: 
  node_type: memory
  type: feedback
  originSessionId: 173e7844-4435-4a58-b777-8e386e5f7db2
---

Running `docker compose -f docker-compose.yml -f docker-compose.worktree.yml up/run` directly (without the env `make` sets: `TREASURY_WORKTREE_NAME`, `TREASURY_APP_PORT`) caused two failures at once (2026-07-09, pine session):

1. **Wrong DB suffix.** `TREASURY_WORKTREE_NAME` defaults to `worktree` (not `pine`), so the container looks for `_worktree` DBs that don't exist, and names itself `treasury-worktree` instead of `treasury-pine`.
2. **Blast radius on shared infra.** Because the base `docker-compose.yml` defines mysql/postgres/minio, the raw invocation collided with the shared `treasury` compose project: it killed `treasury-mysql-1` (Exit 137) AND stopped every sibling worktree app container (main `treasury`, `treasury-dusk`, `treasury-glyph`, `treasury-drift`, `treasury-bloom`, `treasury-patch`) — disrupting other sessions.

**How to apply:** In a worktree, always use `make up` / `make spec FILES=...` / `make sorbet` — they export the correct env and scope to the right compose project. If you must run rspec directly, first `make up` (container must be healthy), then `docker compose ... exec -T -e RAILS_ENV=test -e MOCK_ENTITY_API= app bundle exec rspec <path>` (exec into the ALREADY-running make-managed container; never `up`/`run` raw). Recovery if you do disrupt: `docker start treasury-mysql-1 treasury-postgres-1 treasury-minio-1` then `docker start` each sibling app container by name. Related: [[worktree-branch-checkout]], [[reading-role-specs-concurrent]].