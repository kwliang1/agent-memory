# Treasury Memory Index

Hot list only. Every memory has a line in `CATALOG.md` beside this file: `grep -i <topic> CATALOG.md` before saying no memory exists. Lines carry the lesson, never a status; check `gh`, Linear or prod for state.

## ⚠️ Do not run without Kevin
- [OP #778 return earmark](treasury-op778-return-earmark-selfblock.md) — the reject-first reorder rejects a live $1.8M payment
- [BANK-1746 MMF reconcile](bank-1746-mmf-reconcile.md) — partially applied once; not safe to re-run as written
- [Upekkha on-core](upekkha-oncore-reconciliation-state.md) — two repairs proven harmful; read before touching
- [BANK-1707 Sell #35](project_bank1707-sell35-transfer-representation.md) — destroys rows on a $183k chain
- [BANK-1610 merger sweep](project_bank1610-merger-sweep.md) · [BANK-1623 dup BookTransfer](project_bank1623-dup-booktransfer.md) — raw TP book calls; need a live-balance confirm
- [BANK-1750 bank_confirmed](bank-1750-bank-confirmed-flag.md) — the ticket's premise is inverted

## Kevin's design calls
- [Interchange: George answers, dividends, yield, reversals, sandbox, onboarding, fees](mmf-interchange-integration.md) — the ONLY Interchange note: add new Interchange context as a section there, never a new file. Covers pivot + API map, code gaps vs George, reversals (signed deltas; dividend-reversal type unknown, balance check is the backstop), BANK-2597 onboarding, BANK-1669 stack, BANK-1678 probe, fees, sandbox controls
- [EWA entity_id_type](project_nova701-ewa-entity-id-type.md) — CA branch never returns nova-owned EWAs; the ACH half is untouched on purpose
- [bulk_details](project_pr9139_bulk_details_review.md) — no entity auth, IVC retired for nova, logic in services
- [PaymentActivity review](project_payment_activity_stack_review.md) — contains retracted shape advice; read before quoting it
- [complete! else no-ops by design](reference_complete-else-branch-no-ops-by-design.md) — never add a raise or alert there
- [gate placement carries preconditions](feedback_gate_placement_carries_preconditions.md) — moving a check downstream drops what its branch guaranteed

## Process traps
- [stale shared checkout](treasury-stale-shared-checkout.md) — never read code facts from ~/RubymineProjects/treasury
- [never edit during a suite run](treasury-never-edit-during-suite-run.md) · [Linear cancel closes the linked PR](linear-cancel-closes-linked-pr.md)
- [prior gated branch in review-findings](check-review-findings-for-prior-gated-branch.md) — grep ~/.claude/review-findings before starting; handoffs omit them
- [gate checklist](gate-checklist.md) — run before review round 1 · [frozen snapshot for reviewers](treasury-worktree-gate-frozen-snapshot.md)
- [`gt submit --dry-run` moves main](gt-submit-dry-run-resets-shared-trunk.md) · [worktree upstream is main](worktree-add-sets-upstream-to-main.md) · [Graphite skips signing](graphite-commits-unsigned.md) · [pre-push commits staged files](graphite-prepush-commits-staged.md)

## Run specs and console
- [worktree spec run](treasury-worktree-spec-run.md) · [clean-worktree skips DB drop](worktree-remove-script-skips-db-drop.md) · [dev loop](treasury-worktree-dev-loop.md) · [host spec env](treasury-worktree-spec-env-quotes-and-rustfs.md) · [GemNotFound](treasury-worktree-gemnotfound-gh-token.md) · [no raw docker compose](feedback_worktree-never-raw-docker-compose.md)
- [worktree container eats Prophet traffic](treasury-worktree-shares-nats-prophet.md) · [MOCK_IPSEITY](treasury-mock-ipseity-not-mock-entity-api.md) · [local dev gotchas](treasury-local-dev-gotchas.md)
- [staging UI via console](treasury-staging-ui-check-via-console.md) · [al console](al-console-access.md) · [prod queries myself](treasury-prod-console-access.md) · [pod self-terminates](treasury-console-pod-stdin-eof-workaround.md)

## CI
- [`srb tc` ≠ sorbet CI](srb-tc-is-not-the-sorbet-ci-step.md) — also runs `tapioca dsl --verify` · [enum needs graphql+rbi](treasury-enum-value-ci-and-rollback.md) · [green = Buildkite](feedback_check-buildkite-ci.md) · [program-name enum is hand-maintained](treasury-program-name-enum-hand-maintained.md)
- [lint-staged adds strict sigil](treasury-lint-staged-adds-strict-sigil.md) · [1-value T::Enum](treasury-single-value-tenum-and-struct-sigs.md) · [RustFS OOM flakes](ci-rustfs-sidecar-oom-wipes-buckets.md) · [stub-clobbering flakes](payment-activities-spec-order-flake.md)

## Conventions
- [no API call inside a lock](feedback_no-external-api-call-inside-lock.md) — Kevin: "very bad"; locks guard local work only, dedupe remote side effects with a claim row or idempotency key
- [console repair + PaperTrail](feedback_console_repair_over_task_with_papertrail.md) — one-off fixes may skip the task PR; use update! + oc note, never update_all
- [no fuzzy description matching](feedback_no-fuzzy-description-matching.md) — guards check outcomes or app-templated strings, never LIKE on free text
- [no PaperTrail reads in app logic](feedback_no_papertrail_reads_in_app_logic.md) — derive past state from ledger entries; versions are for audit and repairs
- [nova has no treasury gem](nova-has-no-treasury-gem.md) — nova hand-writes zod schemas over Prophet; a contract change hits it at treasury deploy
- [no T.must](feedback_no-t-must.md) — local + explicit raise-if-nil; grep the diff before committing
- [packwerk/DIBS](feedback_treasury-packwerk-dibs.md) · [class methods](prefer-class-methods-over-value-objects.md) · [sigs aren't guards](treasury-sorbet-sigs-not-runtime-guards.md) · [to_money is dollars](money-to-money-is-dollars-not-cents.md)
- [repair task gotchas](treasury-repair-task-gotchas.md) · [include spec/tasks](spec-neighborhood-must-include-tasks.md) · [schedules live in Temporal](treasury-cron-schedules-cdk8s.md)

## Domain anchors
- [balance-check skill](project_balance-check-diagnosis-skill.md) — run first on any balance-check question · [three balance functions](treasury-three-balance-functions.md)
- [Piermont invoice debits](piermont-operating-account-untracked-invoice-debits.md) — book against Piermont, never SVB
- [INC-5462 Piermont ABAs](inc-5462-piermont-intl-wire-routing.md) — do not collapse · [TP intermediary street](tp-intermediary-requires-street-line-1.md)
- [cross-CA ACH pull landing](ach-pull-cross-ca-sub-landing.md) — revision can't fix it; cash-only USER_OVERRIDE with `ledger_entry:`
- [merge strands in-flight pulls](account-merge-strands-inflight-ach-pulls.md) — MergeService re-points provisioned pulls, not their cash; never move subs, repoint + sweep
- [Temporal Ruby: yield before reading signal state](temporal-ruby-signal-handlers-run-after-main-fiber.md) · [no rspec spies in workflow code](temporal-specs-no-rspec-spies-inside-workflow.md) · [read-only prod console has no Temporal](prod-readonly-console-has-no-temporal.md)
- [Temporal ErrorLogger](temporal-error-logger-reports-every-attempt.md) · [monitors need an unconditional gauge](reference_datadog-monitor-needs-unconditional-gauge.md)
- [concurrent MMF sells deadlock on the fee leg](mmf-concurrent-sells-fee-leg-insufficient-funds.md) — $45 fee validated against available_balance that counts sibling sells; refresh and wire webhook both fail
- [ipseity pin bump touches two gem RBIs + DSL](entity-api-bump-regenerates-two-gem-rbis-and-dsl.md) — entity_prophet_api shares the revision; run gems+dsl verify, not just srb tc
- [worktree PR screenshots](treasury-worktree-pr-screenshots.md) — https port, bun install w/ gh token, playwright channel chrome, gist hosting
- [ipseity client-error contract](project_bank2341-client-error-contract.md) — treasury reads EntityAPI::ErrorCategory, not entity_prophet_api
- [FBO idempotency tokens](project_bank2321-fbo-idempotency-tokens.md) — live token formats are permanent; what Kevin declined
- [activity states filter](project_bank2307-activity-state-filter.md) — raw-state SQL; reassigned→Cancelled gap is deliberate (nova-scoped)
- [DIBS bank-limit holds](dibs-bank-limit-hold-alerting.md) — retries forever silently; split only after cancel; the incident.io webhook makes alerts, never incidents
- [stacked child merges into parent](merging-stacked-child-fuses-into-parent.md) — parent auto-merge then ships the child too; retarget the child to main first
- [Temporal Ruby non_retryable uses bare class name](temporal-ruby-nonretryable-bare-class-name.md) — FQ names never match; default retry is unlimited
- [incident.io dedupes on Sentry issue](incidentio-dedupes-sentry-issue.md) — repeat fatals join the open alert; warning level never pages
- [Sentry MCP can't delete cron monitors](sentry-mcp-cannot-delete-cron-monitors.md) — only per-environment delete; needs a REST token or the UI
- [GitHub stacks: no Part-N lines](feedback_github-stacks-no-part-lines.md) — the stack badge already shows position; manage those branches with gh stack, not gt
- [fund BOs ≠ MajorShareholder](fund-beneficial-owners-not-majorshareholder.md) — writing LP owners as MS breaks verification/Increase/PII; BANK-2075 new role; presenter key bug
- [TP wire Transfers include Frec UUID ids](tp-wire-transfers-frec-uuid-ids.md) — filter wire_ prefix before TP lookups; row 338996 invalid, avoid update! in metadata backfills
- [MMF migration tracker in Arti](mmf-interchange-integration.md) — tracker of record; update rows via the Arti map, not the Claude Doc
