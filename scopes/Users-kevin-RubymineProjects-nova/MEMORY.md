# Nova Project Memory

## Git
- Main branch is `main`, not `master`. Always use `main` for diffs, PRs, and comparisons.
- [reference_nova_forcepush_keeps_approval.md](reference_nova_forcepush_keeps_approval.md) — force-push to a nova PR branch does NOT dismiss existing approvals (stale-approval dismissal off)
- [reference_stacked_pr_peer_forcepush.md](reference_stacked_pr_peer_forcepush.md) — stacking on a peer's in-progress branch: they may force-push; `merge-base --is-ancestor` check + `rebase --onto` their new tip before opening the PR (base = their branch)

## Permissions
- Always allowed: `gh api repos/.../pulls/.../comments` and `gh api repos/.../pulls/.../reviews` to fetch PR comments

## Linear / MCP
- [reference_runlayer_blocks_linear_issue_phrasing.md](reference_runlayer_blocks_linear_issue_phrasing.md) — Linear `save_issue` can 403 (Runlayer) on imperative/injection-like body wording; use descriptive prose

## Review gate

## CI debugging

## Cross-repo contracts

## Anonymity / Roles
- [reference_ninja_role_detection.md](reference_ninja_role_detection.md) — Detect Ninja with permissive `rolesSchema` not the enum schema (whose `.catch([])` drops the whole set); Ninja is a provisioning-admin role (not invitable); `ensurePrismaTransaction` makes data-layer FOR UPDATE locks atomic regardless of caller

## Treasury Client Types
- `TreasuryResponse<T>` transforms snake_case to camelCase via `SnakeToCamelCaseNested`
- So `created_at` in the schema becomes `createdAt` in the type, `account_id` → `accountId`, etc.
- When writing test mocks for `CustomerAccountLedgerEntry`, use camelCase field names
- [reference_treasury_batch_account_lookup.md](reference_treasury_batch_account_lookup.md) — wire batch index hides REJECTED wires; ach batch omits nonexistent ids; EEBR account ids are FK-less strings → dangling pointers; no create/link validation
- [reference_treasury_transfer_state_machine.md](reference_treasury_transfer_state_machine.md) — Treasury transfer state machine doc (in-repo README) + authoritative treasury-repo sources (transfer.rb, info_service.rb); COMPLETED not terminal; monotonic only for INTERNAL

## Entity Matchmaking
- [reference_fsm_engine_commit_boundaries.md](reference_fsm_engine_commit_boundaries.md) — ENTERING commits BEFORE onEnter runs (a porting row reads ENTERING and is healthy); FAILED+ERRORED commit together, so reading execution+event separately can observe an impossible pair; prod vs test Prisma tx timeouts

- [reference_matchmaking_pii_temporal_gate.md](reference_matchmaking_pii_temporal_gate.md) — SUPERSEDED: the scoring gate is gone (#10003); scoring passes rowNumbers not PII to Temporal (#9774), and is live in prod

## Services Pattern
- See `graph/src/services/README.md` for comprehensive guide
- Prefer `andGen` for multiple sequential operations (README: "Prefer andGen for service functions with multiple data fetches")
- `andGen` callback must accept the value parameter from the previous `ok()` result (even if unused as `_authorized`)
- No `async` functions returning `ResultAsync` — return `ResultAsync` directly
- Authz → data fetch → external client call → transform is the standard flow

## Test Environment
- [reference_clients_barrel_mock_gap.md](reference_clients_barrel_mock_gap.md) — `vi.mock('clients')` does NOT cover an import from `clients/venture`; unmocked clients make real HTTP calls and break untouched test files
- [reference_graph_tests_need_just.md](reference_graph_tests_need_just.md) — run graph tests via `just tt graph`, never bare `npx vitest` (no dotenv -> `TypeError: Invalid URL`); 22+ files in entityMatchmaking trips a fork-partition flake; a reused test DB fails unrelated suites
- [reference_app_tests_need_just_turbo.md](reference_app_tests_need_just_turbo.md) — app tests too: `just turbo test --filter=app`, never bare `npx vitest` (dotenv flips code branches; a test green under vitest was red under just)
- Integration tests (using `financialAccountTest` fixture) require dev container / DB — fail with "HTTP/2 sockets" error locally
- Pure unit tests (like `mergeLedgers.test.ts`) run fine locally
- Use `src/` relative paths when running graph tests: `just turbo test --filter=graph --only -- src/path/to/test.ts`

## Resolver Error Handling
- Use `.tuple` destructuring + `switch(error._tag)` + `ensureExhaustive(error)` pattern
- Map: authz → `graphQLForbiddenError()`, notFound → `graphQLNotFoundError()`, others → `new Error(error.message)`
- Import `ensureExhaustive` from `@angellist/std.ts/guard`

## Environment
- [feedback_claude_desktop.md](feedback_claude_desktop.md) — User works from Claude Desktop Code tab (full tool access, don't suggest CLI)

## Worktree Paths
- [feedback_worktree_paths.md](feedback_worktree_paths.md) — Always use worktree root for file paths when in a worktree
- [reference_bare_worktree_bringup.md](reference_bare_worktree_bringup.md) — Bare worktree (no deps/env/DB): copy .npmrc+.env from main, pnpm install, codegen+build, `migrate reset --skip-seed` the shared _test DB; stale local main → use `gh pr create` not `gt submit`

## Codegen
- `just codegen` handles everything (including app/pnpm codegen) — no need to run `pnpm codegen` separately
- Only run codegen when GraphQL fields/types change, before reloading frontend

## Code Style Preferences
- Avoid inline ternaries for JSX props — use if/else blocks above the return to compute values, then pass as props
- Avoid nested ternary expressions — use if/else or early returns for readability
- For blade/modal close animations: track `isOpen` as state, toggle on close, set true when content changes — don't use refs to persist content during close animation
- Never push directly to main — always use a PR branch
- [Pre-push lint with repo biome](feedback_lint_with_repo_biome.md) — run `pnpm run lint` inside the package (repo-pinned biome), never `npx biome check`; version drift caused CI-only format failures
- `useQuery` with `skip` is preferred over `useLazyQuery` + `useEffect` for conditional data fetching in Apollo

## PR Updates
- [feedback_pr_body_markers.md](feedback_pr_body_markers.md) — Always preserve user content above auto-generated markers when updating PR bodies

## Commit hooks
- [feedback_precommit_biome_hook.md](feedback_precommit_biome_hook.md) — Husky pre-commit lint:format fails ("No version is set for command biome"); run package-level `pnpm run lint` then commit with `--no-verify` (see [lint-with-repo-biome](feedback_lint_with_repo_biome.md))

## Type Check
- `just turbo lint:types --filter=graph --only` for type checking
- Pre-existing errors in `types/gen/pothos.ts` (Prisma model drift) — ignore those
- Filter with `grep -v "pothos.ts" | grep "error TS"` to see only relevant errors

## Build Failures
- [feedback_stale_turbo_cache.md](feedback_stale_turbo_cache.md) — When 1 turbo task fails after others cache-hit, suspect stale upstream dist before source-level bugs. Empirically test cache-clear before proposing code fixes.
- [feedback_verify_with_turbo_build_not_tsc_noemit.md](feedback_verify_with_turbo_build_not_tsc_noemit.md) — `tsc --noEmit` can pass while `turbo build` (what CI runs) fails; verify with `turbo build --filter=<pkg> --force` before pushing, and don't skip the pre-push gate on "small" changes
- [reference_nova_entitytype_has_no_fund.md](reference_nova_entitytype_has_no_fund.md) — vulcan `EntityType` has no `'fund'`; a fund's `Entity.type` is `'llc'`. Don't confuse with `COMPANY_TYPES` (KYC-form types, which include `'fund'`)

## LP-wallet matchmaking
- [matchmaking-pii-scoring-architecture.md](matchmaking-pii-scoring-architecture.md) — how PII stays off durable surfaces: DocumentService ingest, reference-passing scoring
- [matchmaking-owner-gate-design.md](matchmaking-owner-gate-design.md) — BANK-1941 / #9830 ENTITY-owner gate (renamed from CommitOwner), NO_OWNER_ACCOUNT, owner_user_id CSV column, id-keyed shells
- [matchmaking-select-candidate-design.md](matchmaking-select-candidate-design.md) — BANK-1923 / #9872 selectCandidate, plus three repo traps a 15-round review found
- [BANK-1943 per-attempt commit design](bank-1943-per-attempt-commit-state.md) — the design and invariants. For current PR state read nova-bank-1943-commit-idempotency; this file's own base reference is stale.
- [nova-local-e2e-matchmaking.md](nova-local-e2e-matchmaking.md) — drive the LP-migration admin UI locally: seed script, treasury NATS collision, minted venture token
- [nova-bulk-upload-house-pattern.md](nova-bulk-upload-house-pattern.md) — the standard upload→parse pattern: Temporal filePostProcessing + lib/workbook.ts

## DocumentService, secrets, PII
- [document-service-at-rest-model.md](document-service-at-rest-model.md) — how DocumentService protects docs at rest, and nova's access-scope gap
- [local-auth-for-documentservice.md](local-auth-for-documentservice.md) — `al auth login -p`, not a local container and not raw `aws sso login`
- [graphql-variable-sanitizer-coverage.md](graphql-variable-sanitizer-coverage.md) — what the variable-log sanitizer redacts after BANK-1927, and what it doesn't
- [nova-prod-secret-provisioning-configtool.md](nova-prod-secret-provisioning-configtool.md) — inline `encrypted|...` in cdk8s configtool config.yaml

## Local dev and worktrees
- [use-worktree-init-skill.md](use-worktree-init-skill.md) — always the worktree-init skill; never hand-roll provisioning
- [spawned-nova-worktree-is-bare.md](spawned-nova-worktree-is-bare.md) — spawned build sessions land in a bare, stale worktree; run `just worktree-init` first
- [nova-lockfile-pnpm-version-trap.md](nova-lockfile-pnpm-version-trap.md) — main's lockfile was written by a newer pnpm than the 10.17.1 pin

## Test and type-check traps
- [graph-tsc-skips-colocated-tests.md](graph-tsc-skips-colocated-tests.md) — `tsc --noEmit` does NOT flag type errors in colocated `src/**/*.test.ts`; run vitest
- [nova-tests-self-poison-warm-db.md](nova-tests-self-poison-warm-db.md) — suites write hardcoded values into UNIQUE columns and never clean up: pass once, fail on a warm DB
- [negative-check-toggles-use-edit.md](negative-check-toggles-use-edit.md) — toggle a fix with the Edit tool when proving a test is load-bearing

## Review
- [ts-best-practices-skill-and-reviewers.md](ts-best-practices-skill-and-reviewers.md) — how the skill is wired, and who actually reviews Kevin's nova PRs

## Moved here from the umbrella scope
- [nova #10090 review — NOTHING POSTED](nova-10090-hand-reconciled-return.md) — 3 blockers plus the FSM/bind facts. Comments are DRAFTED only; the design comment asks yewon to redo the central mechanism, so Kevin sends it.
- [nova 9587 ach return failed vs returned](nova-9587-ach-return-failed-vs-returned.md) — nova PR #9587 review — why a Treasury RETURNED reads as pipeline FAILED, and the one test gap to close before merge
- [nova 9500 bulkupload review](nova-9500-bulkupload-review.md) — nova PR #9500 (NOVA-3681, ctotheameron) bulk-upload email-copy refactor — 2-round adversarial review findings, ranked
- [BANK-1667 #9007 finalize guard](bank-1667-pr9007-state.md) — option C shipped, rebased onto main, MERGEABLE and signed, REVIEW_REQUIRED. Do NOT merge without Kevin.
- [NOVA-3788 service core](nova-3788-service-core.md) — tracking PARENT, split 2026-08-13 into NOVA-3810 sync-seam + NOVA-3811 async-seam. #9497 open, not merged.
- [nova 3849 graphql contract](nova-3849-graphql-contract.md) — NOVA-3849 = entityMatchmaking review-UI GraphQL contract (STUBBED Pothos). RE-SYNCED 2026-08-19 onto renamed base (head fe243d6527)
- [INC-5462 nova fix](nova-piermont-intl-wire-fix.md) — #9436 APPROVED by Yewon, NOT merged, do not merge without Kevin. Venture still collapses the routing.
- [NOVA-3740 transfer reroute](nova-3740-transfer-reroute.md) — #9372+#9396 merged; follow-up #9413 is ready for review with auto-merge OFF. Do NOT merge without Kevin.
- [nova 3738 ach limit error rca](nova-3738-ach-limit-error-rca.md) — NOVA-3738 RCA + fix — bogus ACH limit exceeded $250k red error on internal senders who can wire; regression from PR #6201
- [nova 3776 distribution recipient swap](nova-3776-distribution-recipient-swap.md) — How to swap an in-progress distribution recipient (LLC→individual) across nova+treasury; Bryan Menell/Cusseta case; the FK re-point map + STAGED gate
- [nova 3569 stalled transfer alert](nova-3569-stalled-transfer-alert.md) — NOVA-3569 DONE (PR #9247 merged 2026-08-07) — Temporal-scheduled alert for approved transfers never dispatched to Treasury
- [banking permission backfill gap](nova-banking-permission-backfill-gap.md) — the split migrations never backfilled; 18,726 inconsistent rows. Two PRs merged, but nobody knows whether the backfill ran in prod.
- [nova payment cancel not productized](nova-payment-cancel-not-productized.md) — nova Payment/Distribution cancellation is DB/data-layer-enabled (transitionToCancelled fns exist) but NOT productized — no GraphQL mutation
- [nova fsm stored definition not authoritative](nova-fsm-stored-definition-not-authoritative.md) — nova FSM engine never reads fsm_workflow.definition/canonicalHash back — transitions run off the in-process graph
- [nova buildkite deploy queue block](nova-buildkite-deploy-queue-block.md) — Why a stuck running and failing nova main build blocks ALL newer builds' staging deploys, and how to tell it's a flake safe to cancel.
- [nova worktree dev gotchas](nova-worktree-dev-gotchas.md) — nova repo-level worktree-dev gotchas — headless screenshots blocked by AngelList SSO (emulator is the only offline path)
- [nova 3733 3732 onboarding scripts](nova-3733-3732-onboarding-scripts.md) — NOVA-3733/3732 fund onboarding console scripts delivered — resolved control-person ipseity ids, FlowDash identity-data gaps, bank-program choice
- [onboard vehicle accounts spike](onboard-vehicle-accounts-spike.md) — Spike design — enhancing nova onboardVehicleAccounts.ts to do ipseity identity upsert + roles + KYC + partner-bank program
- [csv entity ingest linear filing](csv-entity-ingest-linear-filing.md) — CSV entity ingest / venture→nova migration — design LOCKED (Path A, TIN primary key)
- [nova 3786 staging schema](nova-3786-staging-schema.md) — NOVA-3786 = LP-matchmaking staging schema; scoped as SKELETON (2 Prisma tables, plain status column), NOT the fsm module
- [lp porting fund5 fund6 csv defects](lp-porting-fund5-fund6-csv-defects.md) — CF Fund 5/6 LP porting (PROD nova): the CSV is a LOOKUP KEY not a payload (nova takes name/type from ipseity) so the TIN decides everything incl
- [nova matchmaking duplicate batch unblock](nova-matchmaking-duplicate-batch-unblock.md) — How to unblock a matchmaking batch blocked as a duplicate upload: stalled predicate, zero delete mutations, the upload-delete cascade map
- [nova matchmaking blank names finalization lag](nova-matchmaking-blank-names-finalization-lag.md) — Blank 'Entity name' column right after staging a matchmaking batch = DocumentService finalization lag, and the UI read has NO retry
- [nova matchmaking upload status stale](nova-matchmaking-upload-status-stale.md) — entity_matchmaking_upload.status sticks on SCORING forever after scoring finishes — the workflow stamps it on entry and never clears it
- [nova directory email banking door](nova-directory-email-banking-door.md) — A DirectoryPerson email is a SECOND, wider door to full banking permissions than the matchmaking port's owner ladder
- [nova matchmaking retro artifact](nova-matchmaking-retro-artifact.md) — LP Wallet Matchmaking as-built-vs-as-specced retro. CANONICAL = the claude.ai artifact (a2818f97…, v19). 22 faults, 16-row drift table, 6 diagrams
- [treasury ewa name collision rca](treasury-ewa-name-collision-rca.md) — RCA — wire to LP Fan Zhang went out named 1 HOUR LUNCH BREAK LLC; root cause is in NOVA's directory payee model, NOT treasury/GHB omnibus
- [feedback nova worktree use the skill](feedback-nova-worktree-use-the-skill.md) — When Kevin asks for a worktree in nova, always use the worktree-dev skill and a full `just worktree-init` — never a bare `git worktree add`

## Previously unindexed, moved from the umbrella
- [CSV entity migration tool — SUPERSEDED](csv-entity-migration-tool.md) — 2026-07-02 design; its join-on-entity_api_id-not-TIN framing was overturned. Read csv-entity-ingest-linear-filing first: Path A makes TIN the primary match key.
- [inc5376 ewa entity flip](inc5376-ewa-entity-flip.md) — INC-5376 nova transfers 403 External wire account not authorized — fix is flipping recipient EWA/EAA entity_id_type ipseity→nova; wire safe
- [nova 9777 insufficient funds block](nova-9777-insufficient-funds-block.md) — PR #9777's pre-insert funds guard shipped and produced its first prod blocks on 2026-08-31 (gryphon-17-llc wire)
- [nova 9873 internal transfer atomicity](nova-9873-internal-transfer-atomicity.md) — nova #9873 discard-on-refusal — verified treasury internal-transfer create IS atomic, so the INTERNAL carve-out is pure conservatism
- [nova adapt table capabilities](nova-adapt-table-capabilities.md) — ADAPT Table has NO expandable rows; client-side table-in-a-blade and client-side Filters both have working nova precedents
- [nova admin recipient treasury link](nova-admin-recipient-treasury-link.md) — nova PR #9417 — admin-only Treasury Account deep-link chip on the distribution recipient blade (On-Nova gated), open for review, not merged
- [BANK-1943 current state](nova-bank-1943-commit-idempotency.md) — #9871 OPEN on base main (#9830 merged 2026-09-09), split into #9871 + #9917, and it overlaps #9932's interim pick-scoped key.
- [nova banking permission 403](nova-banking-permission-403.md) — nova upsertExternalBankReference (and other banking mutation) 403 Forbidden root cause = stale permission set missing canManageFinancialAccounts +
- [nova cdc changes system](nova-cdc-changes-system.md) — How nova rows show up in changes.internal.angellist.com (CDC) — blacklist scope lives in infra not nova, is forward-only/not retroactive
- [nova configtool staging zeus is prod cluster](nova-configtool-staging-zeus-is-prod-cluster.md) — nova's prod-us-west-2-staging-zeus is a staging-LABELLED namespace inside the PRODUCTION cluster
- [nova destroy distribution payment](nova-destroy-distribution-payment.md) — How to hard-delete a nova DistributionPayment + its Payment from the prod REPL — deletion order because everything is onDelete:Restrict.
- [nova entity matchmaking scorer](nova-entity-matchmaking-scorer.md) — nova entityMatchmaking — scoring AND port/wallet (#9696) both NOW LIVE in prod (Kevin, 2026-09-09); console -p runs the deployed image
- [nova entity migration names docservice sso](nova-entity-migration-names-docservice-sso.md) — Entity migration 'Entity name' column blank = expired AWS SSO for DocumentService, NOT missing/bad data
- [nova fund onboarding script](nova-fund-onboarding-script.md) — Nova fund bank-account onboarding — the ipseity+treasury script pattern, two signatory paths, and the control-person==signatory convention.
- [nova lp porting review tab](nova-lp-porting-review-tab.md) — BANK-1885: 7-PR stack #9780→#9795→#9796→#9797→#9798→#9799→#9781 restacked on #9774 (document-identity staging); csv-parser-mirror invariant
- [matchmaking scoring is LIVE](nova-matchmaking-local-e2e.md) — #9833 turned the prod gate on and #10003 removed the flag entirely, so MATCHMAKING_SCORING_ENABLED is dead advice. Keep for the local setup and seeding recipe.
- [owner gate + an OPEN hazard](nova-matchmaking-owner-gate.md) — #9830 makes commitRowCore the single choke point, but nothing validates a CSV owner_user_id: a typo plus an unseen email can hand a real venture user super-admin and banking. No owner audit trail (BANK-2078). Kevin reversed match-only on 2026-09-12.
- [nova matchmaking uncommit fsm dedup](nova-matchmaking-uncommit-fsm-dedup.md) — Matchmaking commit is one-shot: FSM commit/committed events use FIXED per-row idempotency keys
- [nova prisma default pool exhaustion](nova-prisma-default-pool-exhaustion.md) — nova graph/capital-api PrismaClient omits connection_limit, so on 96-vCPU nodes each pod grabs 193 connections and saturates the staging DB
- [nova prisma lint and worktree psql gotchas](nova-prisma-lint-and-worktree-psql-gotchas.md) — nova CI has a lint-prisma step the graph test filter misses; prisma-lint enforces camelCase→snake_case @map word boundaries
- [nova prod db access from bridge](nova-prod-db-access-from-bridge.md) — The bridge/bot session cannot read nova prod DB
- [nova transfer balance reservation traps](nova-transfer-balance-reservation-traps.md) — Five non-obvious traps when reviewing nova transfer/balance code: VBA vs financial-account granularity, permanent orphan CREATED transfers
- [nova transfer kyc event vs poll](nova-transfer-kyc-event-vs-poll.md) — nova distribution transfers — event-driven KYC gate is live but the old polling cron is NOT yet ripped out (BANK-1211 Todo)
- [nova worktree lightweight verify](nova-worktree-lightweight-verify.md) — Verify a nova graph#build tsc error + run pure unit tests in a plain worktree WITHOUT full just worktree-init (docker/DB/codegen)
- [nova worktree portal auth 2fa](nova-worktree-portal-auth-2fa.md) — Logging into a nova worktree portal headless — auth-service routes @angellist.com to Google SSO
- [nova3697 microdeposit institution contract](nova3697-microdeposit-institution-contract.md) — NOVA-3697 microdeposit plaid_institution_id is invalid = app-side Prophet contract mismatch, not Plaid; manual-entry flow has no institution.

## Added
- [n 167 bank institution id](n-167-bank-institution-id.md) — N-167 (stable bank/institution id for transfer recipient matching): DIBS ABA has NO institution id — only routing_number, which is the WRONG grain
- [nova isstring guard convention](nova-isstring-guard-convention.md) — Use isString from @angellist/std.ts/guard for string type-narrowing in nova, not a hand-rolled typeof check (PR #6898)
