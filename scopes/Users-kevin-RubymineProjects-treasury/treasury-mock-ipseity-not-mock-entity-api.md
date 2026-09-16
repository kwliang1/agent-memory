---
name: treasury-mock-ipseity-not-mock-entity-api
description: "In treasury the entity-API mock var is MOCK_IPSEITY, not MOCK_ENTITY_API — the CLAUDE.md pre-push `unset MOCK_ENTITY_API` is a silent no-op there"
metadata:
  node_type: memory
  type: reference
  originSessionId: e3448b36-e106-4f90-a3aa-a714e6b90df8
  modified: 2026-07-28T08:16:01.342Z
---

`~/.claude/CLAUDE.md`'s pre-push gate says to run treasury specs with `unset MOCK_ENTITY_API && bundle exec rspec`. **`MOCK_ENTITY_API` does not exist in treasury** (verified 2026-07-28): `grep -rn MOCK_ENTITY_API app config lib` returns nothing. The real variable is **`MOCK_IPSEITY`** — e.g. `app/models/concerns/customer_account/owner_identity.rb:13`, `app/graphql/query_resolvers/entity_resolver.rb:11`, `app/services/customer_accounts/entities/info_service.rb:18`, `lib/presenter/customer_account.rb:28`, all `ENV['MOCK_IPSEITY'] ? Mocks::EntityApi::Entity : EntityAPI::Entity`. There is also `MOCK_ANGELLIST` for the venture/angellist callbacks.

So `unset MOCK_ENTITY_API` is a **silent no-op** in treasury — the instruction reads as satisfied while changing nothing. Use `env -u MOCK_IPSEITY -u MOCK_ANGELLIST` if the intent is to defeat the mocks.

**What CI actually does:** `.buildkite/pipeline.rb:68-69` sets `MOCK_ANGELLIST: '1'` and `MOCK_IPSEITY: '1'`, so CI runs **with** the mocks on. A local `.env` with no mock vars set (Kevin's, as of 2026-07-28) is therefore *stricter* than CI, not weaker — the reverse of what the rule assumes. Consequence: specs that call the real entity API fail locally with `WebMock::NetConnectNotAllowedError: GET http://ipseity:3001/api/entities/...` while passing on CI. Two such pre-existing failures at `origin/main@19a52139f`: `spec/graphql/mutations/data_change_requests/update_entity_compliance_questions_spec.rb:88` and `spec/graphql/query_resolvers/outgoing_transfers_resolver_spec.rb:37`. Don't chase those as regressions — reproduce with CI's env (`-e MOCK_IPSEITY=1 -e MOCK_ANGELLIST=1`) before concluding anything.

**Also: treasury CI rspec is Knapsack Pro *Queue* mode** (`bin/ci/rspec` → `rake knapsack_pro:queue:rspec` when `BUILDKITE_PARALLEL_JOB_COUNT` is set). Shard membership is assigned dynamically at runtime, so a failing `rspec-treasury-N` is **not** a reproducible file set and a rebuild reshuffles it — you cannot re-run "that shard" locally. Identify the example from the Buildkite log instead; note there is no `bk` CLI and no `BUILDKITE_API_TOKEN` in the bridge env, and rspec reports as a GitHub *status* (not a check-run) so `gh api .../check-runs` yields no annotation text.

Related: [[treasury-worktree-dev-loop]], [[spec-neighborhood-must-include-tasks]].
