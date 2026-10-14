# Nova Memory Index

Hot list only. Every memory has a line in `CATALOG.md` beside this file: `grep -i <topic> CATALOG.md` before saying no memory exists. Lines carry the lesson, never a status; check `gh`, Linear or prod for state.

## Git, PRs, review
- Always allowed: `gh api repos/.../pulls/.../comments` and `.../reviews`
- [signing is a ruleset](nova-signing-is-a-ruleset-not-branch-protection.md) — Contents-API commits are unsigned and won't merge · [`%G?` lies](git-ssh-sig-reads-as-unsigned.md)
- [unstack after parent squash](nova-unstack-after-parent-squash-merge.md) — probe with `--merge-base`; `gt parent` goes empty
- [sweep AI threads every push](feedback-handle-ai-threads-on-every-push.md) · [declined finding keeps round clean](feedback-declined-finding-does-not-reset-gate.md)
- [ts-best-practices + reviewers](ts-best-practices-skill-and-reviewers.md) · [Runlayer 403s Linear wording](reference_runlayer_blocks_linear_issue_phrasing.md)
- [gate checklist](gate-checklist.md) — run before review round 1

## Type-check, build, CI
- Type-check: `just turbo lint:types --filter=graph --only`; ignore `types/gen/pothos.ts` errors
- Codegen: `just codegen` covers app; [capital-api schema first](nova-codegen-order-capital-api-first.md), exits 0 anyway
- [turbo replays cached results](turbo-caches-lint-and-test-results.md) — bare `tsc` / `--force` for reported numbers · [`--force` breaks local tests](nova-turbo-build-force-breaks-local-tests.md)
- [`tsc --noEmit` ≠ `turbo build`](feedback_verify_with_turbo_build_not_tsc_noemit.md) · [graph tsc OOMs as clean](graph-tsc-ooms-and-reads-as-clean.md) · [filter tsc by cause](tsc-filter-by-cause-not-by-path.md)
- [lint-prisma CI step](nova-prisma-lint-and-worktree-psql-gotchas.md) · [k8s steps have no checkout](nova-k8s-steps-have-no-checkout.md) · [known CI flakes](nova-ci-flakes-2026-10-14.md)

## Tests
- [graph tests via `just tt graph`](reference_graph_tests_need_just.md) · [app tests via just turbo](reference_app_tests_need_just_turbo.md); use `src/`-relative paths
- [4 forks, one test DB](graph-tests-share-one-db-across-4-forks.md) · [suites self-poison](nova-tests-self-poison-warm-db.md) · [private test DB](nova-worktree-private-test-db.md)
- [`vi.mock('clients')` misses submodules](reference_clients_barrel_mock_gap.md) · [mock factory deadlock](nova-vitest-mock-factory-deadlock.md) · [src must not import factories](nova-src-must-not-import-test-factories.md)

## Worktrees
- [use the worktree-init skill](use-worktree-init-skill.md) · [port collision / missing test DB](nova-worktree-init-port-collision-and-test-db.md) · [sync clones a failed migration](nova-worktree-sync-clones-failed-migration.md)
- [`.env` may aim at shared nova DB](nova-worktree-env-points-at-shared-nova-db.md) · [multi-treasury NATS split](nova-multi-treasury-nats-roundrobin.md) · [worktree root paths](feedback_worktree_paths.md)

## Conventions
- Services: `graph/src/services/README.md`; `andGen` for sequential ops; never `async` returning `ResultAsync`; authz → data → client → transform
- Resolvers: `.tuple` + `switch(error._tag)` + `ensureExhaustive`; authz → `graphQLForbiddenError()`, notFound → `graphQLNotFoundError()`
- UI: no nested ternaries in JSX props; `useQuery` + `skip` over `useLazyQuery`; blade close: track `isOpen` as state
- [`isString` guard](nova-isstring-guard-convention.md) · [lint inside the package](feedback_lint_with_repo_biome.md) · [ADAPT Table / Filters / Stat traps](nova-adapt-stat-tooltip-filters-traps.md)
- [fund `Entity.type` is `llc`](reference_nova_entitytype_has_no_fund.md) · [prod console query](reference_nova_graph_prod_console_query.md) · [bridge can't read prod DB](nova-prod-db-access-from-bridge.md)

## Domain anchors
- [fixture claims must be RUN](nova-matchmaking-fixture-claims-must-be-run.md) · [FSM commit boundaries](reference_fsm_engine_commit_boundaries.md) · [stored definition not authoritative](nova-fsm-stored-definition-not-authoritative.md)
- [transfer state machine](reference_treasury_transfer_state_machine.md) · [transfer/balance traps](nova-transfer-balance-reservation-traps.md) · [INVESTMENT balance is cash only](treasury-investment-balance-is-cash-only.md)
- [blank entity name = expired SSO](nova-entity-migration-names-docservice-sso.md) · [staging-zeus is prod cluster](nova-configtool-staging-zeus-is-prod-cluster.md)
- [banking 403s](nova-banking-permission-403.md) · [payment cancel isn't productized](nova-payment-cancel-not-productized.md) · [DocumentService local auth](local-auth-for-documentservice.md)
