- [One-off scripts: loadable .rb for rails console, not rake](feedback_one_off_scripts.md) — deliver a `MyJob.run(**kwargs)` module to `load` in rails console; PR OK, deploy skippable
- [HTTP calls use Faraday](feedback_http_client.md) — Faraday is the repo convention; Net::HTTP / HTTParty are legacy being migrated away from
- [ISOBIC free-text defeats Google geocoder; pre-processing needed](project_google_geocoding_preprocessing.md) — BANK-1296 finding: 60% no_match on raw input. Root causes: Latin-1 strip in InfoService + ISOBIC free-text defeats Google NLP. BANK-1274 needs pre-processing.
- [ipseity is the entity API](project_ipseity_is_entity_api.md) — producer not consumer; no MOCK_ENTITY_API to unset; just `bundle exec rspec`
- [ipseity specs run inside docker](feedback_ipseity_specs.md) — `docker exec ipseity-app-1 bundle exec rspec ...`; host shell lacks ENTITY_API_SECRET
- [CI builds are ssh-only; private git gems need git@ remotes](project_ci_ssh_only_git_gems.md) — `github:` shorthand = https = breaks on private repos; failure hides behind docker layer cache until Gemfile.lock changes
- [Rails 8.1 upgrade gotchas](reference_rails8_upgrade_gotchas.md) — concrete 7.1→8.1 breakages (puma/rackup, multi-action routes, zeitwerk/tapioca, connection_pool 3, ProxyObject, secrets.yml, factory_bot) from ipseity PR #1556; reusable for treasury BANK-1845
- [ipseity UUIDs are un-dashed](reference_ipseity_uuid_undashed.md) — Entity#id/entity_api_id is 32-char no-dash (uuid.rb cast); raw-SQL uuid reads come back dashed → normalize with delete('-')
- [Sentry sql breadcrumb leaks inlined SQL values](reference_ipseity_sentry_sql_breadcrumb_pii.md) — filter is key-based; pass PII as bind params, never inline; add scoped compound keys to filter_parameters; also covers the #cause-chain leak + the NUL-in-batched-SQL gotcha
- [ipseity prod entity table sizes + al console recipe](reference_ipseity_entity_table_sizes.md) — entities ~620k, people ~288k, companies ~173k (hundred-k not millions → GIN over GiST for trgm); pull read-only via `al console exec -p -a ipseity`

## Moved here from the umbrella scope
- [bank 1757 passport pan bidx find by identity](bank-1757-passport-pan-bidx-find-by-identity.md) — ipseity PR #1549 (BANK-1757) passport+PAN blind indexes + find_by_identity; consolidated into IdentityLookupService, owned by dcetlin
- [nova 3784 ipseity lookup by tin](nova-3784-ipseity-lookup-by-tin.md) — NOVA-3784 ipseity entities:lookup_by_tax_id batch handler BUILT — ipseity PR #1547 ready-for-review (NOT merged), watching for AI feedback
- [BANK-1586 in-progress no-advance](bank-1586-inprogress-no-advance.md) — SHIPPED and live: the fail-closed ADVANCE_FROM_STAGES allow-list runs in kyc_review.rb, tweaked twice since (latest #1573, 2026-08-26).
- [BANK-1586 response-received](bank-1586-response-received-plan.md) — #1522 merged then REVERTED (#1526) on a misdiagnosis, but the re-land #1529 IS merged and the feature is LIVE. Treasury fix #8485 is obsolete: #8458 deleted the path.
- [ipseity swap entity types](ipseity-swap-entity-types.md) — ipseity DOES support changing an existing entity's entity_type (e.g. Trust→IRA) via Entities::UpdateService.swap_entity_types! — destructive

## Previously unindexed, moved from the umbrella
- [bank1586 alloy response received mover](bank1586-alloy-response-received-mover.md) — BANK-1586 update the Zap is really an ipseity code change; where the Alloy pending-docs→Flowdash flow lives, how to move a KYC task stage
- [gate checklist](gate-checklist.md) — CI-parity checks to run once before review round 1 (read by CLAUDE.md gate step 0).
- [worktree specs via sibling container](ipseity-worktree-specs-sibling-container.md) — strip the quotes from .devcontainer/.env before --env-file; start ipseity-temporal-1 first.
- [BANK-2341 PR B scope](project_bank2341-pr-b-scope.md) — raise sites, rescue fixes, IRA swap, metric; same Linear issue
