---
name: treasury-kill-secondary-account-wire-reroute
description: "treasury PR #8531 — deleted legacy 'route to secondary account' failed-wire admin fallback, end to end. OPEN, not merged."
metadata: 
  node_type: memory
  type: project
  originSessionId: 341f36e6-ded7-4f4f-b3c4-607a0dd51bef
  modified: 2026-08-13T19:30:48.789Z
---

Treasury PR **#8531** (branch `kevinliang/treasury-kill-secondary-account-wire-reroute`, off origin/main): removed the legacy admin **"Route To Secondary Account"** button on a failed `OutgoingWire` — the fallback that re-routed a wire through a secondary/backup sub-account (fund-migration `Transfer` + repoint `sub_account_id`). Product sign-off in Slack C045AHA7WFQ p1786643884933569 (Grace Cunnie "havent used this in ages / im fine with this"; Thomas Ambrosia "cant see why we would need this").

**Killed end to end:** `Mutations::OutgoingWires::RouteToSecondaryAccount` + GraphQL field + its RBI; `OutgoingWires::SecondaryAccountService`; `OutgoingWirePolicy#route_to_secondary_account?`; `route_to_secondary_account` enum value + `VALID_ADDITIONAL_ACTIONS` entry; frontend wiring in `OutgoingWireDetail.tsx`; regenerated `schema.graphql/json`, `graphql.ts`, `apolloTypePolicies.json`. 12 files, +3/−302. No specs existed for the path. **NOT** the separate create/display secondary-account feature (`PartnerBank::Program::CreateSecondaryAccount`, `isSecondaryAccount`) — that's distinct and untouched. Sibling actions `route_through_svb`/`resubmit_to_tag`/`provision_and_submit`/normal `submit` untouched.

**Status: OPEN, MERGEABLE, signed, CI running — do NOT merge without Kevin.** Gate passed: sorbet + RBI-sync + frontend tsc clean, 93 sibling/normal-path specs green, 5 independent Opus reviews over 2 rounds all clean.

**Reusable treasury gotcha (schema regen):** the generated GraphQL schema (`schema.graphql`/`schema.json`) is checked by CI `bin/ci/ensure_server_in_sync` (re-runs `rake graphql:schema:dump` + `cmp`), so it MUST be regenerated, not hand-edited. Host can't boot Rails ([[treasury-local-dev-gotchas]]) but **docker can**: worktree `make setup-worktree && make up` boots the app container (mounts worktree code via `.:/app`), then `make graphql` (backend dump + frontend codegen) + `make rbi`. Snag: worktree image on origin/main may be missing newer gems (hit `sentry-ruby 6.6.2` GemNotFound) vs the stale shared `treasury_app-gems` volume → `docker compose ... run --rm --no-deps app bundle install` first. Specs DO run in-container: `docker exec -e RAILS_ENV=test -e MOCK_ENTITY_API= treasury-<worktree> bundle exec rspec ...`. biome binary is absent from the container volume — can't lint frontend locally, rely on CI.
