---
name: venture-worktree-dev-loop
description: "How to run venture specs, GraphQL codegen and typecheck from an isolated git worktree, including the cross-repo treasury-gem trick"
metadata: 
  node_type: memory
  type: reference
  originSessionId: 8fd804ba-bcab-4f77-adeb-d769f4b515da
  modified: 2026-07-28T05:42:59.102Z
---

Verified 2026-07-27 in `.worktrees/venture-1506`. Venture worktrees are NOT like treasury's — there is no `make setup-worktree` and no per-worktree containers.

**Start the app through direnv or nothing works.** `make up` is `direnv exec . overmind start -l monolith,sidekiq,prophet,fundraising,webpack` (`Makefile:82`) — direnv is what loads `.env.development` into the process env. Starting `overmind start` bare silently omits it, and the Next app then 500s with `INTERNAL_GRAPHQL_URI environment variable is not set` while Rails looks fine (`/` still 302s, so a healthcheck won't catch it). This cost me an entire debugging session; I mistook it for missing mocks. Restore a stack the same way, and verify BOTH ports (`3001` → 302, `3003` → 301).

**Containers are shared and fixed-name.** `make up-docker` fails with `Conflict. The container name "/angellist_mysql" is already in use`. Just start the existing ones: `docker start angellist_mysql al_es` (redis is usually already up). Specs need MySQL, Elasticsearch (:9200) **and** `banking_pg` (:5439, `PG::ConnectionBad` otherwise) — `docker start angellist_mysql al_es al_redis banking_pg`. (2026-10-20)

**Node deps must be installed twice** — root `pnpm install` does not cover the workspace: also `cd frontend/fundraising && pnpm install`, or `apollo`/`graphql-codegen` are "command not found".

**Codegen:** `bin/rake graphql:export_backend` (writes `schema.graphql` + `schema.json`) then `pnpm graphql:export:fundraising` (writes `frontend/fundraising/schema.ts`, `fragmentTypes.json`, `apolloTypePolicies.json`). CI enforces both via `bin/ci/ensure_graphql_types_in_sync fundraising`. Typecheck is package-local: `cd frontend/fundraising && pnpm typecheck` — there is no root script.

**Cross-repo work against an unmerged treasury gem:** temporarily point ONLY lines 31-32 of the Gemfile at the branch —
`sed -i '' "31s|branch: 'main'|branch: <branch>|; 32s|...|" Gemfile && bundle install`
— then `git checkout -- Gemfile Gemfile.lock` before committing. Do NOT `sed` `branch: 'main'` globally; it also hits `entity_api`, `entity_prophet_api` and `warehouse-reporting`. Both treasury gems share one git source, so bumping one moves `treasury_api` too, and the RBI filenames embed the source revision → after a real bump CI needs `bundle update treasury_prophet_api && make gem-rbis` (both; `ensure_sorbet_in_sync` runs `tapioca gems --verify`).

**The shared test DB is usually stale** relative to a worktree branched off older main — expect unrelated factory failures like `no superclass method 'syndicator_investment_percentage' for FundCampaign`. That is environmental, NOT your change. Do **not** run `rake db:test:prepare` to fix it — it would downgrade the shared DB under other concurrent sessions. Verify your own examples by line number instead.

**Rendering an LP funding-accounts page locally is a mock quagmire.** Local treasury 404s/500s on most `/api/*`. Beyond `MOCK_TREASURY=1` + `MOCK_IPSEITY=1` you still have to gate, one at a time: `cryptos/deposits`, `plaids/microdeposit_verifications`, and the `InvestmentEntities::InfoService` pending_* readers. Then GraphQL POSTed by hand from the console 422s on CSRF. Budget hours, not minutes — or wait until the dependency you need is real.

Related: [[shared-checkout-worktree-isolation]], [[treasury-worktree-dev-loop]], [[claude-in-chrome-unavailable-on-bridge]].
