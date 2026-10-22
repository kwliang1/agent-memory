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
- [EWA entity_id_type](project_nova701-ewa-entity-id-type.md) — CA branch never returns nova-owned EWAs; the ACH half is untouched on purpose
- [bulk_details](project_pr9139_bulk_details_review.md) — no entity auth, IVC retired for nova, logic in services
- [PaymentActivity review](project_payment_activity_stack_review.md) — contains retracted shape advice; read before quoting it
- [complete! else no-ops by design](reference_complete-else-branch-no-ops-by-design.md) — never add a raise or alert there
- [gate placement carries preconditions](feedback_gate_placement_carries_preconditions.md) — moving a check downstream drops what its branch guaranteed

## Process traps
- [stale shared checkout](treasury-stale-shared-checkout.md) — never read code facts from ~/RubymineProjects/treasury
- [never edit during a suite run](treasury-never-edit-during-suite-run.md) · [Linear cancel closes the linked PR](linear-cancel-closes-linked-pr.md)
- [gate checklist](gate-checklist.md) — run before review round 1 · [frozen snapshot for reviewers](treasury-worktree-gate-frozen-snapshot.md)
- [`gt submit --dry-run` moves main](gt-submit-dry-run-resets-shared-trunk.md) · [worktree upstream is main](worktree-add-sets-upstream-to-main.md) · [Graphite skips signing](graphite-commits-unsigned.md) · [pre-push commits staged files](graphite-prepush-commits-staged.md)

## Run specs and console
- [worktree spec run](treasury-worktree-spec-run.md) · [dev loop](treasury-worktree-dev-loop.md) · [host spec env](treasury-worktree-spec-env-quotes-and-rustfs.md) · [GemNotFound](treasury-worktree-gemnotfound-gh-token.md) · [no raw docker compose](feedback_worktree-never-raw-docker-compose.md)
- [worktree container eats Prophet traffic](treasury-worktree-shares-nats-prophet.md) · [MOCK_IPSEITY](treasury-mock-ipseity-not-mock-entity-api.md) · [local dev gotchas](treasury-local-dev-gotchas.md)
- [al console](al-console-access.md) · [prod queries myself](treasury-prod-console-access.md) · [pod self-terminates](treasury-console-pod-stdin-eof-workaround.md)

## CI
- [`srb tc` ≠ sorbet CI](srb-tc-is-not-the-sorbet-ci-step.md) — also runs `tapioca dsl --verify` · [enum needs graphql+rbi](treasury-enum-value-ci-and-rollback.md) · [green = Buildkite](feedback_check-buildkite-ci.md) · [program-name enum is hand-maintained](treasury-program-name-enum-hand-maintained.md)
- [lint-staged adds strict sigil](treasury-lint-staged-adds-strict-sigil.md) · [1-value T::Enum](treasury-single-value-tenum-and-struct-sigs.md) · [RustFS OOM flakes](ci-rustfs-sidecar-oom-wipes-buckets.md) · [stub-clobbering flakes](payment-activities-spec-order-flake.md)

## Conventions
- [console repair + PaperTrail](feedback_console_repair_over_task_with_papertrail.md) — one-off fixes may skip the task PR; use update! + oc note, never update_all
- [no fuzzy description matching](feedback_no-fuzzy-description-matching.md) — guards check outcomes or app-templated strings, never LIKE on free text
- [packwerk/DIBS](feedback_treasury-packwerk-dibs.md) · [class methods](prefer-class-methods-over-value-objects.md) · [sigs aren't guards](treasury-sorbet-sigs-not-runtime-guards.md) · [to_money is dollars](money-to-money-is-dollars-not-cents.md)
- [repair task gotchas](treasury-repair-task-gotchas.md) · [include spec/tasks](spec-neighborhood-must-include-tasks.md) · [schedules live in Temporal](treasury-cron-schedules-cdk8s.md)

## Domain anchors
- [balance-check skill](project_balance-check-diagnosis-skill.md) — run first on any balance-check question · [three balance functions](treasury-three-balance-functions.md)
- [Piermont invoice debits](piermont-operating-account-untracked-invoice-debits.md) — book against Piermont, never SVB
- [INC-5462 Piermont ABAs](inc-5462-piermont-intl-wire-routing.md) — do not collapse · [TP intermediary street](tp-intermediary-requires-street-line-1.md)
- [cross-CA ACH pull landing](ach-pull-cross-ca-sub-landing.md) — revision can't fix it; cash-only USER_OVERRIDE with `ledger_entry:`
- [merge strands in-flight pulls](account-merge-strands-inflight-ach-pulls.md) — MergeService re-points provisioned pulls, not their cash; never move subs, repoint + sweep
- [Temporal ErrorLogger](temporal-error-logger-reports-every-attempt.md) · [monitors need an unconditional gauge](reference_datadog-monitor-needs-unconditional-gauge.md)
- [concurrent MMF sells deadlock on the fee leg](mmf-concurrent-sells-fee-leg-insufficient-funds.md) — $45 fee validated against available_balance that counts sibling sells; refresh and wire webhook both fail
- [ipseity pin bump touches two gem RBIs + DSL](entity-api-bump-regenerates-two-gem-rbis-and-dsl.md) — entity_prophet_api shares the revision; run gems+dsl verify, not just srb tc
- [Interchange Schedule A fees](reference_interchange_schedule_a_fees.md) — fee schedule is in the platform agreement docx in #nova-interchange; wire $25→$15, ACH waived, invoiced to AL not the customer.
- [worktree PR screenshots](treasury-worktree-pr-screenshots.md) — https port, bun install w/ gh token, playwright channel chrome, gist hosting
- [BANK-2341 client-error contract](project_bank2341-client-error-contract.md) — treasury reads EntityAPI::ErrorCategory, not entity_prophet_api
- [BANK-2321 FBO tokens](project_bank2321-fbo-idempotency-tokens.md) — live token formats are permanent; what Kevin declined
- [BANK-2307 activity state filter](project_bank2307-activity-state-filter.md) — raw-state SQL; reassigned→Cancelled gap is deliberate (nova-scoped)
