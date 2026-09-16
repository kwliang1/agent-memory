---
name: local-dev-mocking
description: How to mock external services and demo venture features locally — full playbook lives in the repo skill .claude/skills/local-venture-demo/SKILL.md
metadata: 
  node_type: memory
  type: project
  originSessionId: cc2cfd62-e6a4-42d7-8933-ac0a05308ad1
---

A project skill `local-venture-demo` (`.claude/skills/local-venture-demo/SKILL.md`, created 2026-06-12, untracked — Kevin may commit it separately) holds the full local-demo playbook: mock flags (`MOCK_IPSEITY`/`MOCK_TREASURY`/`MOCK_COMPTROLLER` in `.env.development`, piecemeal — ungated call sites need local-only guards), overmind restart procedure, the dev-stack wedge problem (load FC Admin pages once, iterate via Apollo `refetch` not page reloads), demo-data finder patterns, and the broken local treasury container (`customer_accounts` always 500s: `uninitialized constant MaintenanceTasks`).

Key hazards: `gt modify -a` and `git add -A` sweep uncommitted local hacks (auth stubs, mock gates) into feature branches — stage explicit paths; lint-staged failures during `gt modify` can roll back working-tree edits (recover from the `lint-staged automatic backup` stash). Related: [[feedback_skip_local_linting]].

CRITICAL cross-suite gotcha: `lib/mocks/entity_api/entity.rb` (`Mocks::EntityAPI::Entity`) is NOT dev-only — the **CPTR test suite uses it** because `.env.test` sets `CPTR_MOCK_IPSEITY=1`/`CPTR_MOCK_TREASURY=1` (note the `CPTR_` prefix; the bare `MOCK_IPSEITY` my venture gates check is NOT set in CI test). Every `:cptr_corporation` factory validates `entity.company?`, so `company?` MUST stay hardcoded `true` — making it `entity_type == :COMPANY` (false for the `:PERSON` default) silently fails ~all CPTR specs with "Entity must be a company in order to be represented as a corporation" → every RSpec shard fails fast (~3.5min, Sorbet still passes). `person?` and `company?` are both intentionally `true`; each consumer checks the one it needs (venture KYC checks `person?` first, CPTR checks `company?`). Don't "fix" the apparent incoherence. Local repro requires `CPTR_MOCK_IPSEITY=1 bundle exec rspec spec/backend/cptr/...` AND a synced test DB (`rake db:test:prepare` — a stale local DB masks it as a misleading `corporation_id NOT NULL` error instead).
