# Nova Project Memory

## Git, PRs, review
- Always allowed: `gh api repos/.../pulls/.../comments` and `.../reviews` to fetch PR comments
- [reference_nova_forcepush_keeps_approval.md](reference_nova_forcepush_keeps_approval.md) — force-push to a nova PR branch does NOT dismiss existing approvals
- [reference_stacked_pr_peer_forcepush.md](reference_stacked_pr_peer_forcepush.md) — stacking on a peer's in-progress branch
- [nova-unstack-after-parent-squash-merge.md](nova-unstack-after-parent-squash-merge.md) — parent squash-merged: probe with `--merge-base` or get bogus conflicts; `gt parent` goes EMPTY; a stacked child reads CLEAN only until retarget, then BLOCKED at 0 approvals
- [git-ssh-sig-reads-as-unsigned.md](git-ssh-sig-reads-as-unsigned.md) — `%G?` prints `N` for SSH-signed commits with no allowedSignersFile; the commit IS signed — check `git cat-file` before "fixing" signing
- [signing is a ruleset, not branch protection](nova-signing-is-a-ruleset-not-branch-protection.md) — `branches/main/protection` says `required_signatures:false` and is wrong; Contents-API commits are unsigned and won't merge
- [feedback_pr_body_markers.md](feedback_pr_body_markers.md) — preserve user content above the auto-generated markers
- [feedback_precommit_biome_hook.md](feedback_precommit_biome_hook.md) — Husky pre-commit lint:format fails ("No files…")
- [feedback-handle-ai-threads-on-every-push.md](feedback-handle-ai-threads-on-every-push.md) — every push ends by sweeping ALL PRs in the stack for AI review threads, replying, and resolving via GraphQL
- [feedback-two-reviewers-per-round.md](feedback-two-reviewers-per-round.md) — gate reviewer count per round
- [feedback-declined-finding-does-not-reset-gate.md](feedback-declined-finding-does-not-reset-gate.md) — a declined finding (even a new one) leaves the round clean; only acted-on feedback resets
- [ts-best-practices-skill-and-reviewers.md](ts-best-practices-skill-and-reviewers.md) — how the skill is wired, and who actually reviews Kevin's nova PRs
- [feedback-arti-is-default-artifact-tool.md](feedback-arti-is-default-artifact-tool.md) — publish designs/docs to arti, link the URL in chat
- [reference_runlayer_blocks_linear_issue_phrasing.md](reference_runlayer_blocks_linear_issue_phrasing.md) — Linear `save_issue` 403s (Runlayer) on imperative/injection-like wording; use descriptive prose

## CI, build, type-check traps
- [datadog sync (FIXED by #10636 on 9/30)](nova-datadog-sync-not-applying.md) — apply was dead 9/16–9/30; now applied from CI with conflict detection
- [nova-k8s-steps-have-no-checkout.md](nova-k8s-steps-have-no-checkout.md) — test/lint jobs never run `.buildkite/hooks/*`; source arrives via the image, tagged by head sha
- [github-merge-ref-is-frozen-at-head-push.md](github-merge-ref-is-frozen-at-head-push.md) — `refs/pull/N/merge` is not a live merge with main
- [turbo-caches-lint-and-test-results.md](turbo-caches-lint-and-test-results.md) — `just turbo lint:types` and `test` replay cached results; use bare `tsc` and `--force` for any number you report
- [feedback_stale_turbo_cache.md](feedback_stale_turbo_cache.md) — when 1 turbo task fails after others cache-hit
- [feedback_verify_with_turbo_build_not_tsc_noemit.md](feedback_verify_with_turbo_build_not_tsc_noemit.md) — `tsc --noEmit` can pass while `turbo build` (what CI runs) fails
- [nova-turbo-build-force-breaks-local-tests.md](nova-turbo-build-force-breaks-local-tests.md) — `turbo build --force` wipes the Prisma engine and leaves `packages/*/dist` shadowing `src`; unfiltered `just turbo build` repairs it
- [tsc-filter-by-cause-not-by-path.md](tsc-filter-by-cause-not-by-path.md) — classify every tsc error by cause; a my-files-only grep hid a CI blocker from a newly-required field
- [graph-tsc-ooms-and-reads-as-clean.md](graph-tsc-ooms-and-reads-as-clean.md) — graph `tsc` OOMs (exit 134) without `--max-old-space-size=6144` and the crash greps as 0 errors; also rebuild `packages/core` after a stacked-branch checkout
- [graph-tsc-skips-colocated-tests.md](graph-tsc-skips-colocated-tests.md) — `tsc --noEmit` does NOT flag type errors in colocated tests (but see the OOM entry above — that was likely the real cause)
- [nova-prisma-lint-and-worktree-psql-gotchas.md](nova-prisma-lint-and-worktree-psql-gotchas.md) — CI has a lint-prisma step the graph test filter misses
- [nova-buildkite-deploy-queue-block.md](nova-buildkite-deploy-queue-block.md) — why a stuck running-and-failing nova build blocks the deploy queue
- [nova-lockfile-pnpm-version-trap.md](nova-lockfile-pnpm-version-trap.md) — main's lockfile was written by a newer pnpm
- [Datadog log facets are UI-only](nova-datadog-log-facets-ui-only.md) — not in ops/datadog; a group_by on an unfaceted @attr renders empty; list them via /api/ui/event-platform/logs/facets
- [nova-codegen-order-capital-api-first.md](nova-codegen-order-capital-api-first.md) — app codegen `Unknown type`: dump capital-api's schema BEFORE graph's; codegen exits 0 anyway
- Type-check: `just turbo lint:types --filter=graph --only`; ignore pre-existing `types/gen/pothos.ts` errors (`grep -v pothos.ts | grep "error TS"`)
- Codegen: `just codegen` covers app too; only needed when GraphQL fields/types change

## Session cost & observability
- [hydra-raindrop-session-id-mismatch.md](hydra-raindrop-session-id-mismatch.md) — Raindrop keys on `claudeSessionId`, not the announced `session_id`
- [hydra-cancelled-protocol-stale-nudges.md](hydra-cancelled-protocol-stale-nudges.md) — a cancelled adversarial review keeps nudging; `advance()` errors "no active protocol" — ignore them
- [review-gate-cache-cost-accounting.md](review-gate-cache-cost-accounting.md) — subagents are a separate bucket; dedupe `message.id`-last; the gate's 5m-TTL and long-context-tail wastes

## Test environment
- [reference_graph_tests_need_just.md](reference_graph_tests_need_just.md) — run graph tests via `just tt graph`
- [reference_app_tests_need_just_turbo.md](reference_app_tests_need_just_turbo.md) — app tests too; bare vitest flips env-dependent code paths
- [reference_clients_barrel_mock_gap.md](reference_clients_barrel_mock_gap.md) — `vi.mock('clients')` does NOT cover submodules
- [nova-tests-self-poison-warm-db.md](nova-tests-self-poison-warm-db.md) — suites write hardcoded values into UNIQUE columns
- [selectcandidate-repick-test-is-flaky-on-main.md](selectcandidate-repick-test-is-flaky-on-main.md) — that re-pick test fails beside sibling suites on main too; how to run the revert-to-main control
- [graph-tests-share-one-db-across-4-forks.md](graph-tests-share-one-db-across-4-forks.md) — 4 forks, ONE test DB: a new factory-writing test file can fail an unrelated sibling
- [nova-vitest-mock-factory-deadlock.md](nova-vitest-mock-factory-deadlock.md) — a `vi.mock` factory that dynamically imports deadlocks
- [nova-src-must-not-import-test-factories.md](nova-src-must-not-import-test-factories.md) — `test/factories` in `graph/src` drags 61 test files into the prod build
- [negative-check-toggles-use-edit.md](negative-check-toggles-use-edit.md) — toggle a fix with the Edit tool when mutation-testing
- Use `src/`-relative paths for graph tests; `financialAccountTest` integration tests need the dev container/DB

## Local dev and worktrees
- [worktree sync clones a FAILED migration](nova-worktree-sync-clones-failed-migration.md) — sync says Completed while the DB sits ~14 migrations behind; check `_prisma_migrations` first
- [multiple treasury containers split one NATS](nova-multi-treasury-nats-roundrobin.md) — Prophet round-robins across separate MySQL DBs; treasury reads silently miss ~(n-1)/n of the time
- [use-worktree-init-skill.md](use-worktree-init-skill.md) — always use the worktree-init skill
- [feedback-nova-worktree-use-the-skill.md](feedback-nova-worktree-use-the-skill.md) — when Kevin asks for a worktree
- [feedback_worktree_paths.md](feedback_worktree_paths.md) — always use the worktree root for file paths
- [spawned-nova-worktree-is-bare.md](spawned-nova-worktree-is-bare.md) — spawned build sessions land in a bare worktree
- [reference_bare_worktree_bringup.md](reference_bare_worktree_bringup.md) — bare worktree (no deps/env/DB) bring-up
- [nova-worktree-env-points-at-shared-nova-db.md](nova-worktree-env-points-at-shared-nova-db.md) — worktree `.env` can aim `POSTGRES_URL` at the shared `nova` DB; also: venture may run from a *worktree*, find it via `ps`, not `docker`
- [nova-worktree-private-test-db.md](nova-worktree-private-test-db.md) — shared `nova_test` goes stale; clone a private one, and run `pnpm run test` in graph since `just` overrides POSTGRES_URL
- [nova-worktree-dev-gotchas.md](nova-worktree-dev-gotchas.md) — repo-level worktree-dev gotchas
- [nova-worktree-lightweight-verify.md](nova-worktree-lightweight-verify.md) — verify a graph#build tsc error cheaply
- [nova-worktree-portal-auth-2fa.md](nova-worktree-portal-auth-2fa.md) — logging into a worktree portal headless
- [nova-prod-db-access-from-bridge.md](nova-prod-db-access-from-bridge.md) — the bridge/bot session cannot read nova prod DB
- [feedback_claude_desktop.md](feedback_claude_desktop.md) — Kevin works from the Claude Desktop Code tab
- [reference_hydra_transcribe_sidecar.md](reference_hydra_transcribe_sidecar.md) — voice notes via hydra's sidecar

## Conventions and patterns
- [nova-isstring-guard-convention.md](nova-isstring-guard-convention.md) — use `isString` from `@angellist/std.ts/guard`
- [feedback_lint_with_repo_biome.md](feedback_lint_with_repo_biome.md) — run `pnpm run lint` inside the package
- [nova-adapt-table-capabilities.md](nova-adapt-table-capabilities.md) — ADAPT Table has NO expandable rows
- [nova-adapt-single-select-filter-unclearable.md](nova-adapt-single-select-filter-unclearable.md) — a single-select Filters facet in `defaultApplied` can't be cleared; Reset is swallowed
- [nova-adapt-stat-tooltip-filters-traps.md](nova-adapt-stat-tooltip-filters-traps.md) — `Stat` is the pressable card, but a `Card` kills its selected halo, `Tooltip` clobbers its `onPress`, and a controlled `Filters` loses the search debounce
- [reference_ninja_role_detection.md](reference_ninja_role_detection.md) — detect Ninja with a permissive `rolesSchema`
- [reference_nova_entitytype_has_no_fund.md](reference_nova_entitytype_has_no_fund.md) — vulcan `EntityType` has no `'fund'`; a fund's `Entity.type` is `'llc'`
- Services: see `graph/src/services/README.md`; prefer `andGen` for sequential ops; never `async` returning `ResultAsync`; flow is authz → data → client → transform
- Resolvers: `.tuple` + `switch(error._tag)` + `ensureExhaustive` (from `@angellist/std.ts/guard`); authz → `graphQLForbiddenError()`, notFound → `graphQLNotFoundError()`
- UI: no inline/nested ternaries in JSX props — compute above the return; `useQuery` + `skip` over `useLazyQuery` + `useEffect`
- Blade/modal close animation: track `isOpen` as state; don't use refs to persist content during close

## DocumentService, PII, secrets
- [document-service-at-rest-model.md](document-service-at-rest-model.md) — how DocumentService protects docs at rest
- [local-auth-for-documentservice.md](local-auth-for-documentservice.md) — `al auth login -p`, not a local container
- [nova-entity-migration-names-docservice-sso.md](nova-entity-migration-names-docservice-sso.md) — blank 'Entity name' = expired AWS SSO, NOT bad data
- [graphql-variable-sanitizer-coverage.md](graphql-variable-sanitizer-coverage.md) — what the variable-log sanitizer covers
- [nova-prod-secret-provisioning-configtool.md](nova-prod-secret-provisioning-configtool.md) — inline `encrypted|...` in cdk8s configtool
- [nova-configtool-staging-zeus-is-prod-cluster.md](nova-configtool-staging-zeus-is-prod-cluster.md) — prod-us-west-2-staging-zeus is a staging-LABELLED namespace in the PRODUCTION cluster
- [nova-cdc-changes-system.md](nova-cdc-changes-system.md) — how nova rows reach changes.internal.angellist.com

## LP-wallet matchmaking / entity migration
- [matchmaking-pii-scoring-architecture.md](matchmaking-pii-scoring-architecture.md) — how PII stays off durable storage
- [reference_matchmaking_pii_temporal_gate.md](reference_matchmaking_pii_temporal_gate.md) — SUPERSEDED: scoring gate gone (#10003)
- [nova-matchmaking-local-e2e.md](nova-matchmaking-local-e2e.md) — scoring is LIVE; #9833 turned the prod gate on
- [nova-local-e2e-matchmaking.md](nova-local-e2e-matchmaking.md) — drive the LP-migration admin UI locally
- [matchmaking-owner-gate-design.md](matchmaking-owner-gate-design.md) — BANK-1941 / #9830 ENTITY-owner gate design
- [nova-matchmaking-owner-gate.md](nova-matchmaking-owner-gate.md) — #9830 makes commitRowCore the single choke point, plus an OPEN hazard
- [matchmaking-select-candidate-design.md](matchmaking-select-candidate-design.md) — BANK-1923 / #9872
- [bank-1943-per-attempt-commit-state.md](bank-1943-per-attempt-commit-state.md) — BANK-1943 per-attempt commit design and invariants
- [nova-bank-1943-commit-idempotency.md](nova-bank-1943-commit-idempotency.md) — BANK-1943 current state; #9871 OPEN
- [nova-matchmaking-uncommit-fsm-dedup.md](nova-matchmaking-uncommit-fsm-dedup.md) — commit is one-shot: FSM dedup
- [reference_fsm_engine_commit_boundaries.md](reference_fsm_engine_commit_boundaries.md) — ENTERING commits BEFORE onEnter; FAILED+ERRORED commit together
- [nova-fsm-stored-definition-not-authoritative.md](nova-fsm-stored-definition-not-authoritative.md) — the engine never reads `fsm_workflow.definition` back
- [nova-entity-matchmaking-scorer.md](nova-entity-matchmaking-scorer.md) — scoring and classification
- [nova-bank-2161-tin-miss-name-fallback.md](nova-bank-2161-tin-miss-name-fallback.md) — #10676: TIN no_match falls back to name+type (review-capped); sticky name-lookup mocks mask it
- [matchmaking-stuck-scoring-repair.md](matchmaking-stuck-scoring-repair.md) — verify/repair an upload stuck at scoring
- [nova-matchmaking-duplicate-batch-unblock.md](nova-matchmaking-duplicate-batch-unblock.md) — unblock a batch blocked as a duplicate upload
- [nova-matchmaking-blank-names-finalization-lag.md](nova-matchmaking-blank-names-finalization-lag.md) — blank names = DocumentService finalization lag; the UI read has NO retry
- [nova-matchmaking-upload-status-stale.md](nova-matchmaking-upload-status-stale.md) — `entity_matchmaking_upload.status` goes stale
- [nova-10243-deletebatch-fixture-fix.md](nova-10243-deletebatch-fixture-fix.md) — #10243 unblocks red main
- [nova-lp-porting-review-tab.md](nova-lp-porting-review-tab.md) — BANK-1885 7-PR stack
- [lp-porting-fund5-fund6-csv-defects.md](lp-porting-fund5-fund6-csv-defects.md) — CF Fund 5/6 LP porting defects (PROD)
- [nova-matchmaking-retro-artifact.md](nova-matchmaking-retro-artifact.md) — as-built-vs-as-specced retro
- [fixture claims must be RUN, never reasoned](nova-matchmaking-fixture-claims-must-be-run.md) — 0-for-4 reasoned vs 4-for-4 executed, one day, one file.
- [BANK-1897 matchmaking o11y](nova-matchmaking-fsm-observability.md) — `fsm.*` already measures the row FSM; the FAILED-state gauge watches an empty set.
- [nova-bulk-upload-house-pattern.md](nova-bulk-upload-house-pattern.md) — the standard upload→parse pattern
- [nova-3786-staging-schema.md](nova-3786-staging-schema.md) — NOVA-3786 LP-matchmaking staging schema
- [nova-3849-graphql-contract.md](nova-3849-graphql-contract.md) — NOVA-3849 review-UI GraphQL contract
- [csv-entity-ingest-linear-filing.md](csv-entity-ingest-linear-filing.md) — CSV entity ingest / venture→nova migration
- [csv-entity-migration-tool.md](csv-entity-migration-tool.md) — SUPERSEDED 2026-07-02 design
- [nova-directory-email-banking-door.md](nova-directory-email-banking-door.md) — a DirectoryPerson email is a SECOND door
- [nova-9500-bulkupload-review.md](nova-9500-bulkupload-review.md) — PR #9500 bulk-upload review

## Treasury, transfers, payments
- [treasury-investment-balance-is-cash-only.md](treasury-investment-balance-is-cash-only.md) — net_liquidation_value == total_balance on INVESTMENT; MMF sits on a sibling
- [reference_treasury_transfer_state_machine.md](reference_treasury_transfer_state_machine.md) — transfer state machine; COMPLETED not terminal; monotonic only for INTERNAL
- [reference_treasury_batch_account_lookup.md](reference_treasury_batch_account_lookup.md) — wire batch index hides REJECTED wires; EEBR account ids are FK-less
- [nova-transfer-balance-reservation-traps.md](nova-transfer-balance-reservation-traps.md) — five traps in transfer/balance code
- [nova-transfer-kyc-event-vs-poll.md](nova-transfer-kyc-event-vs-poll.md) — distribution transfers, KYC event vs poll
- [nova-9873-internal-transfer-atomicity.md](nova-9873-internal-transfer-atomicity.md) — #9873 discard-on-refusal atomicity
- [nova-9777-insufficient-funds-block.md](nova-9777-insufficient-funds-block.md) — #9777 pre-insert funds guard
- [nova-9587-ach-return-failed-vs-returned.md](nova-9587-ach-return-failed-vs-returned.md) — why a Treasury RETURNED reads as pipeline FAILED
- [nova-3738-ach-limit-error-rca.md](nova-3738-ach-limit-error-rca.md) — bogus "ACH limit exceeded" RCA + fix
- [nova-3740-transfer-reroute.md](nova-3740-transfer-reroute.md) — #9372+#9396 merged; #9413 follow-up
- [nova-3776-distribution-recipient-swap.md](nova-3776-distribution-recipient-swap.md) — swap an in-progress distribution recipient
- [nova-3569-stalled-transfer-alert.md](nova-3569-stalled-transfer-alert.md) — NOVA-3569 DONE (#9247 merged)
- [nova-payment-cancel-not-productized.md](nova-payment-cancel-not-productized.md) — Payment/Distribution cancel is not productized
- [nova-destroy-distribution-payment.md](nova-destroy-distribution-payment.md) — how to hard-delete a distribution payment
- [nova-10090-hand-reconciled-return.md](nova-10090-hand-reconciled-return.md) — #10090 review, NOTHING POSTED; 3 blockers
- [nova-piermont-intl-wire-fix.md](nova-piermont-intl-wire-fix.md) — INC-5462; #9436 APPROVED, NOT merged
- [inc5376-ewa-entity-flip.md](inc5376-ewa-entity-flip.md) — INC-5376 transfers 403 "External wire account not found"
- [treasury-ewa-name-collision-rca.md](treasury-ewa-name-collision-rca.md) — RCA: wire went out under the wrong LP name
- [nova-admin-recipient-treasury-link.md](nova-admin-recipient-treasury-link.md) — #9417 admin-only Treasury link
- [n-167-bank-institution-id.md](n-167-bank-institution-id.md) — N-167 stable bank/institution id
- [nova3697-microdeposit-institution-contract.md](nova3697-microdeposit-institution-contract.md) — NOVA-3697 is an app-side Prophet contract mismatch, not Plaid

## Banking platform, permissions, onboarding
- [nova-banking-permission-403.md](nova-banking-permission-403.md) — `upsertExternalBankReference` and other banking 403s
- [nova-banking-permission-backfill-gap.md](nova-banking-permission-backfill-gap.md) — the split migrations never backfilled
- [nova-prisma-default-pool-exhaustion.md](nova-prisma-default-pool-exhaustion.md) — graph/capital-api PrismaClient pool exhaustion
- [nova-fund-onboarding-script.md](nova-fund-onboarding-script.md) — fund bank-account onboarding
- [nova-3733-3732-onboarding-scripts.md](nova-3733-3732-onboarding-scripts.md) — NOVA-3733/3732 console scripts
- [onboard-vehicle-accounts-spike.md](onboard-vehicle-accounts-spike.md) — spike design for vehicle accounts
- [nova-3788-service-core.md](nova-3788-service-core.md) — tracking PARENT, split into NOVA-3810 + others
- [bank-1667-pr9007-state.md](bank-1667-pr9007-state.md) — BANK-1667 #9007 finalize guard; option C shipped
- [query nova prod via al console](reference_nova_graph_prod_console_query.md) — app is `nova-graph`; push a .ts + `npx tsx`, not the REPL. Schema traps: `inviteEmail`, `sentStatus`.
- [gate checklist](gate-checklist.md) — CI-parity checks to run once before review round 1 (read by CLAUDE.md gate step 0).
