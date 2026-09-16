# Treasury Memory Index

Hooks answer "open this file?" — detail lives in the file, not here.

## Working rules that are NOT treasury-specific
These apply everywhere but were only ever reachable from this scope. Promotion to `~/.claude/CLAUDE.md` is per-entry, not done wholesale — several need generalizing first.

- [CI green means Buildkite green](feedback_check-buildkite-ci.md) — verify via `gh pr checks` or Buildkite, listing each step. Body names treasury-only step names; generalize before promoting.

## Treasury dev environment
- [al console access](al-console-access.md) — prod read works; write (`-w`) needs GlobalConsoleWriters. Scripted push/exec/pull recipe.
- [console RBAC is auth-flow dependent](reference_al-console-treasury-rbac.md) — Forbidden in treasury-ro when SSO is stale.
- [worktree spec-run recipe](treasury-worktree-spec-run.md) — env + docker host-port fixups to boot RSpec from a throwaway worktree.
- [never raw docker compose in a worktree](feedback_worktree-never-raw-docker-compose.md) — collides with the shared project; use the make targets.
- [worktree compose hits the wrong DB](reference_worktree-compose-env-wrong-db.md) — `TREASURY_WORKTREE_NAME` defaults to `worktree`.
- [worktree husky pre-push](reference_worktree-husky-prepush-link.md) — symlink `.husky/_/husky.sh`, don't reach for `--no-verify`.
- [worktree pre-commit uses stale local main](reference_worktree-precommit-hook-stale-main.md) — lists hundreds of files in a worktree.
- [worktree SSR auth gap](reference_worktree-ssr-auth-gap.md) — Next SSR auth fetch targets the main checkout's treasury:3001.
- [worktree dev auth user](project_worktree-dev-auth.md) — needs venture@angellist.com for auto-login; belongs in seed_local_admin.rb.
- [can't check out a worktree branch in main](feedback_worktree-branch-checkout.md) — use the worktree, or cherry-pick.
- [Graphite commits unsigned](graphite-commits-unsigned.md) — `gt modify/create` skip signing; re-sign with `git rebase -f --gpg-sign main`.
- [RubyMine pins old Ruby](rubymine-pins-old-ruby.md) — project SDK overrides `.tool-versions`; set it to 3.4.8.
- [treasury packwerk / DIBS](feedback_treasury-packwerk-dibs.md) — root can't reference DIBS models; go through the `dibs_api` facade.
- [schema.json via rake, not make](reference_schema-json-rake-not-make-graphql.md) — `rake graphql:schema:dump` is CI's method.
- [Knapsack queue mode](reference_treasury-knapsack-queue-mode.md) — adding examples reshuffles node co-location and can surface latent order bugs.
- [reading-role specs need :concurrent](project_reading-role-specs-concurrent.md) — `connected_to(role: :reading)` resolvers.
- [maintenance_tasks Array collections](reference_maintenance-task-array-collection-gotcha.md) — positional resume silently skips under a shrinking filter; use a Relation.
- [Temporal sig widening](reference_temporal-sig-widen-inflight-drain.md) — widen the WORKFLOW execute sig too, or sorbet.rb bites.
- [prefer class methods over value objects](prefer-class-methods-over-value-objects.md) — stateless extractions are `class << self`.

## Balance checks
- [OP balance-check classification](op-balance-check-classification.md) — OP debits ledger only at `complete!`; submitted-but-uncompleted = treasury-ahead false break.
- [in-progress adjustment writer](project_balance-check-in-progress-writer-gap.md) — RESOLVED; writer shipped #8147, live since 2026-07-09. Stuck = past-critical unadjusted only.
- [balance-check destination-credit fix](project_balance-check-destination-credit-fix.md) — #8146 deletes the speculative V2 destination-credit adjustment that minted ~198 false positives; flipper external_payment_processor_balance stays OFF until it ships.
- [balance-check resolutionTransfers field](project_balance-check-resolution-followup.md) — adds a GraphQL resolutionTransfers field: only one resolution_transfer_id FK is stored, but each inactive sub-account produces its own migration transfer.
- [non-resolution diagnosis](project_bc-resolution-56174-462253.md) — CA 56174 benign, CA 462253 stuck in ACCOUNT_MERGE; resolved-field semantics.
- [ACH pull phantom diff](project_bc-469607-ach-pull-phantom.md) — CA 469607 $10k; #8806 classifies in-flight pulls as pending settlements.
- [legacy fallback removal](project_bank1866-legacy-fallback-removal.md) — #8796 removes the record_type provenance fallback.
- [incoming ACH unledgered recon](incoming-ach-unledgered-recon.md) — dropped TP webhook + dead backstop = silent unledgered credit.
- [TP nil transaction-balance filters](tp-nil-transaction-balance-filters.md) — nil is normal; three drop-filters, one was the bug (#8638).
- [ACH pull submission paths](ach-pull-submission-paths.md) — three live crons; why a submission guard needs more than one chokepoint.

## MMF
- [CT rail retire](project_bank1493-mmf-ct-rail-retire.md) — BANK-1493, #8320, drain-confirmed.
- [CT orders spec CI fix](project_bank1493-ct-orders-spec-cifix.md) — #8369, spec-only repair, task kept runnable.
- [BANK-1492 carve-out cleanup](project_bank1492-carveout-blocked.md) — NOT blocked; draft #8351 prod-validated. Awaiting Kevin's ~$9.92M inter-FBO coordination with Venture, then run.
- [V2 migration execution](project_bank1698-migration-execution.md) — 7 contract-lapse backfills + 2 dangling-ref orders.
- [confirmation key fix](project_bank1508-mmf-confirmation-key-fix.md) — symbol/string key bug, #8366.
- [DRY refactor](project_bank1511-mmf-dry-refactor.md) — #8370; 2 of 4 ticket items obsolete.
- [BANK-1548 terminal guard](project_bank1548-terminal-guard.md) — #8365; the body recommends CLOSING it as YAGNI. Reviewer and Kevin both pushed back; the scenario is unreachable.
- [buy fee model](project_bank1585-mmf-buy-fee-model.md) — position leg is `net_value_cents`.
- [BANK-1707 Sell #35 — GREENLIT, not yet run](project_bank1707-sell35-transfer-representation.md) — Kevin chose option A; reworked task in OPEN #8384 supersedes merged #8373. Prod dry_run PASSED 2026-07-28, cleared to execute. Force-destroys 4 LedgerEntries, 2 BookTransfers and IncomingWire #249815 on a $183,301 chain.
- [divergence pipeline](project_bank1486-mmf-divergence-pipeline.md) — #8067, folded into the 8h balance-check pipeline.
- [async MMF sell](project_bank1910-async-mmf-sell.md) — #8746, SLA-aware paging policy.
- [yield adapter](project_bank1951-yield-adapter.md) — #8772, YieldService via `Adapters::Base.for(...)`.
- [hourly yield reflection](project_bank1952-hourly-mmf-yield.md) — schedule lives in the Temporal registry, not cdk8s.
- [yield drift repair](project_repair-319597-yield-drift.md) — guard failed because a manual reflection added $4,602.05.
- [sell guard Sentry](project_sentry-mmf-sell-guard.md) — 7590196523 "Insufficient Funds".
- [account_purpose follow-ups](mmf-account-purpose-followups.md) — deferred after #7929.
- [FBO ↔ MMF association](project_fbo-mmf-association.md) — via `owner_entity_api_id`, not just IVC.

## Projects and PR state
- [BANK-2089 inactive-SA stall](project_bank2089-inactive-sa-forward-stall.md) — #8876 shipped; T252581/T248904 repair still outstanding.
- [BANK-1360 pull-return cascade](project_bank1360-ach-pull-return-cascade.md) — balance-driven async cancel + balance-aware guard. PR #8778 OPEN, pushed 2026-09-04, CI green; supersedes #8576/#8588, both closed.
- [BANK-1592 self-transfer](project_bank1592-self-transfer-fix.md) — funds-migration double-count.
- [BANK-1594 incoming SLA](project_bank1594-incoming-sla.md) — 2-PR stack (#8185 + #8186) on #8161; #8182/#8187/#8194 all closed.
- [BANK-1604 book-transfer reversal](project_bank1604-book-transfer-reversal.md) — maintenance task reversing a completed BookTransfer.
- [BANK-1610 merger sweep](project_bank1610-merger-sweep.md) — $129.70, CA 89173→89163. NOT executed: raw TP book call, no ledger record, awaiting Kevin's live-balance confirm.
- [BANK-1620 URL persistence](project_bank1620-url-persistence.md) — balance-checks admin filters in query params.
- [BANK-1623 duplicate BookTransfer](project_bank1623-dup-booktransfer.md) — $2,950.05 on CA 396654. NOT executed: raw TP book call, awaiting Kevin's live-balance confirm.
- [BANK-1634 BNY cert rotation](project_bank1634-bny-cert-rotation.md) — SUPERSEDED: the cert-key mismatch was a misdiagnosis. Keep only for the configtool install recipe; read bank1634-bny-cert-is-servercert before acting.
- [BANK-1666 FBO over Prophet](project_bank1665-nova-fbo-prophet.md) — filename says 1665, the issue is **BANK-1666**. NOVA FBOs are standalone, no IVC; #8305 green.
- [BANK-1668 EWA entity check](project_bank1668-nova-ewa-entity-check.md) — #8306 enforces source == NOVA.
- [BANK-1793 JPM decouple](project_bank1793-jpm-decouple.md) — merged; 4 post-merge commits on a recreated branch.
- [BANK-1581 follow-ups](project_bank1581-followups.md) — DIBS return gap, ACH auto-transfer, reconcile_tran.
- [SVB funds-migration SLA](project_svb-funds-migration-sla.md) — BAI2 file-settled coverage.
- [on-core preauth transfer desc](project_oncore-preauth-transfer-desc.md) — #8702, id-less "Transfer" descs.
- [banking dashboard review skill](project_banking-dashboard-review-skill.md) — #8671, weekly review → Linear task-cutting.
- [BANK-1952 PR body](bank1952_pr_body.md) — draft text only.

## Incidents
- [INC-5355 NSF classifier removal](project_inc5355-nsf-classifier-removal.md) — P0; always page on V2 errored transitions.
- [INC-5413 BNY→Piermont $10.44](project_inc5413-bny-piermont-1044.md) — auto-swept because BNY isn't in the excluded set.

## Datadog
- [drift forces a 2-PR stack](reference_datadog-drift-two-pr-stack.md) — pull PR, then change PR; prod is the source of truth.
- [monitors need an unconditional gauge](reference_datadog-monitor-needs-unconditional-gauge.md) — an only-while-unhealthy gauge fires once and never recovers.
- [CI owns the datadog sync](project_datadog-docs-ci-owns-sync.md) — #8314; never run local op-triggering `make dd-*`.

## Moved here from the umbrella scope
- [treasury local dev gotchas](treasury-local-dev-gotchas.md) — treasury repo — host-side rspec can't boot from tooling (secret env), and git push needs --no-verify (broken husky) but keep --gpg-sign
- [treasury ca subaccount provisioning gotchas](treasury-ca-subaccount-provisioning-gotchas.md) — Treasury CustomerAccount + subaccount provisioning traps — owner_entity uniqueness is INVESTMENT-only
- [treasury prophet ledger consumed by nova](treasury-prophet-ledger-consumed-by-nova.md) — Treasury's paginated Prophet CustomerAccount::Ledger endpoint is consumed by NOVA (not just venture/ACE) — Kevin corrected this 2026-09-14
- [treasury fatal incident automation gap](treasury-fatal-incident-automation-gap.md) — Why treasury fatal exceptions sometimes create NO incident.io incident
- [treasury zylalabs deprecated](treasury-zylalabs-deprecated.md) — ZylaLabs SWIFT/IBAN lookup is fully dead in treasury (code #7799, config #8880, vendor account canceled)
- [BANK-1750 bank_confirmed flag](bank-1750-bank-confirmed-flag.md) — #8591 open, not merged, but Kevin PIVOTED 2026-08-19: the ticket premise is INVERTED (the real problem is over-counting unresolved, a collection gap not a classification one). Don't advance without his call.
- [BANK-1787 pending-verification park/resume](bank-1787-pending-verification-park-resume.md) — core #8570 and o11y #8589 MERGED. #8572 (BANK-1829) is the single open PR: approved, CI green, ready to merge, awaiting Kevin.
- [op ivc cascade mirror wrong direction](op-ivc-cascade-mirror-wrong-direction.md) — RCA — OP IvcCascadeMirror plan models mirror leg backwards (Mirror→OnCore), illegal; froze OPs 848/1058/1197 in processing
- [transfer 229393 ivc pull balance bypass](transfer-229393-ivc-pull-balance-bypass.md) — Transfer 229393 ivc_pull pos2 insufficient funds deadlock — root cause + treasury PR #8586 fix
- [BANK-1360 linkage investigation](bank-1360-cancel-pushes-on-pull-return.md) — SUPERSEDED: the #8576/#8588 FK stack was closed. Keep for the linkage analysis; current state is project_bank1360-ach-pull-return-cascade.
- [BANK-1445 ACH index regression — LIVE](bank-1445-status-and-ach-index-regression.md) — scopes 1-2 moot, but the external_ach_accounts.index entity_id_type regression is LIVE at 121 errors/14d. Fix is #8574, open and mergeable — DO NOT MERGE without Kevin.
- [bank 1764 ach pull block submission](bank-1764-ach-pull-block-submission.md) — BANK-1764 SHIPPED (treasury PR #8454): block ACH pull submission for denylisted/inactive CAs at 3 live chokepoints before bank contact. CI green
- [BANK-1746 MMF reconcile — RAN AND ERRORED IN PROD](bank-1746-mmf-reconcile.md) — #8455 merged and run 2026-08-10: 16 of 17 applied, #17 errored, CA 295243 left mid-repair (later confirmed un-itemizable and dropped). Do NOT re-run as-is. Run 05af1c67 (2026-08-18) flagged 3 new divergences incl. CA 407126 +$45.
- [bank 1719 stuck ach pull recovery](bank-1719-stuck-ach-pull-recovery.md) — BANK-1719 treasury PR #8443 — recover stuck ACH pulls with no active sub-account instead of 500ing; DIBS-routing fix pushed, CI GREEN
- [treasury kill secondary account wire reroute](treasury-kill-secondary-account-wire-reroute.md) — treasury PR #8531 — deleted legacy 'route to secondary account' failed-wire admin fallback, end to end. OPEN, not merged.
- [BANK-1858 flowdash divergence](bank-1858-flowdash-divergence-monitor.md) — reframed from a Slack alert to Metabase cards 35228/35229, built but not yet on dash 4188. Alert code (BANK-1860) PAUSED pending sign-off. Found 4 payments live-stuck in compliance review, oldest 160 days.
- [bank 1506 imad omad trace](bank-1506-imad-omad-trace.md) — BANK-1506 IMAD/OMAD trace — treasury PR MERGED; venture PR #31974 SHIPPED to ready-for-review (rebased/redesigned/green), NOT merged
- [op errored state requeue](op-errored-state-requeue.md) — treasury OutgoingPayment has NO errored state; how bank errors + requeue actually work, the DIBS routing bug, and the #8605 ops-vs-eng design conflict
- [op v2 rerollout gate model](op-v2-rerollout-gate-model.md) — OP V2 re-rollout: the 3 flipper-gate axes, and why 8 of 9 retro error categories cross all gates instead of nesting under them
- [bank 1847 balance check unaddressed taxonomy](bank-1847-balance-check-unaddressed-taxonomy.md) — BANK-1847 (internal-ahead classifier gap) filed + 5-day balance-check sweep taxonomy: which unresolved cases each fix covers and which are NOT
- [bank 1721 proration refund rehome](bank-1721-proration-refund-rehome.md) — BANK-1721 spike — move proration-refund endpoint from treasury→venture + fix the SELECT…FOR UPDATE lock (root cause = bank HTTP under with_lock)
- [mmf interchange integration](mmf-interchange-integration.md) — MMF 2nd-provider Linear project pivoted APEX→Interchange (2026-08-14). Two tracks (sweep + explicit-order) both Backlog, sweep-first leaning
- [MMF IVC migration admin](mmf-ivc-migration-admin.md) — treasury #8120 + venture #31124 both pushed, NOT merged. Venture sorbet CI is intentionally RED until #8120 lands. Local e2e was VERIFIED end to end 2026-08-19.
- [mmf sell category cptr impact](mmf-sell-category-cptr-impact.md) — MMF sell cash leg flipped MMF_SELL→TRANSFER (intended, BANK-1474/1476/1477); comptroller unaffected — values MMF by balance
- [mmf account ui invested liquidated bug](mmf-account-ui-invested-liquidated-bug.md) — BANK-2091 SHIPPED to review: venture #35445 (Invested/Liquidated tiles) + treasury #8865 (Balance column = NLV + overview). MMF trades write 2 legs
- [ark nova transaction api settled at](ark-nova-transaction-api-settled-at.md) — Nova→Ark bank Transactions API needs a per-txn settlement/posting date; treasury only has a bank-true value date for SVB wires — a real sourcing gap.
- [transfer 227895 svb wire split gap](transfer-227895-svb-wire-split-gap.md) — RCA Transfer 227895 stranded $2.03M SVB wire — PR #8126 ACH-split gap in the wire-reassignment (revise_ledger_entry_destination!) path
- [OP #778 false-positive return — DO NOT REORDER](treasury-op778-return-earmark-selfblock.md) — CA 465829's BAI2 exception is a false-positive returned wire. Do NOT apply the reject-first reorder: it would wrongly Reject a live $1.8M payment. Prod already reconciled by console 2026-08-20; code fix #8618 open, not merged.
- [Upekkha/IKYAM $198,300 wire](upekkha-ikyam-wire-reconciliation.md) — on-core sits −$198,300, cure transfer T233849 stuck sent_pending_arrival (verified 2026-08-19). SUPERSEDED by upekkha-oncore-reconciliation-state (flint, 2026-08-31) — read that first; two repairs there are proven harmful.
- [plaid microdeposit blocked account 500](plaid-microdeposit-blocked-account-500.md) — treasury create_microdeposit_verification returns 500 on Plaid BANK_TRANSFER_ACCOUNT_BLOCKED; should be 422
- [treasury stale shared checkout](treasury-stale-shared-checkout.md) — The shared /Users/kevin/RubymineProjects/treasury checkout runs weeks behind origin/main — never read code facts from it
- [treasury never edit during suite run](treasury-never-edit-during-suite-run.md) — A treasury full-suite rspec run is not interruptible: editing files mid-run OR killing the run both produce scattered fake failures in unrelated
- [graphite prepush commits staged](graphite-prepush-commits-staged.md) — Treasury repo — a Graphite pre-push hook auto-commits any leftover STAGED files onto the current branch at push time

## Previously unindexed, moved from the umbrella
- [bai2 458 rtp debit](bai2-458-rtp-debit.md) — BAI2 code 458 = RTP debit (return of an incoming RTP); the three gates a new BAI2 type code must clear in treasury, not just the constants file
- [bai2 ach debit attribution](bai2-ach-debit-attribution.md) — How to attribute a treasury BAI2 'AngelList Payment <id> FBO AngelList Clients' ACH-debit line to the exact Transfer/CrossTransfer
- [balance-check gap analysis, Jul 2026](balance-check-gaps-discussion.md) — BANK-1592 and BANK-1594 were filed out of it, so nothing awaits selection. Holds the classify-never-credit rule for pending credits.
- [bank 1542 tp postal code verify](bank-1542-tp-postal-code-verify.md) — BANK-1542 verify TP no longer requires postal_code on counterparty creation — prod-console test script staged
- [bank 1584 frec adapter migration](bank-1584-frec-adapter-migration.md) — BANK-1584 executed — routed MMF OrderService order mechanics through the Frec adapter + adapter now owns funded_by_mmf_position via a predicate
- [BANK-1665 APEX/AscendOS spike](bank-1665-apex-mmf-discovery.md) — the verdict and ProviderPlan argument. SUPERSEDED: the programme pivoted APEX→Interchange 2026-08-14.
- [bank1634 bny cert is servercert](bank1634-bny-cert-is-servercert.md) — BANK-1634 install new BNY prod cert — the attached cert is BNY's OWN server cert, not ours; treasury doesn't pin it → likely no-op close-out.
- [cptr banking transfer sync backdate trap](cptr-banking-transfer-sync-backdate-trap.md) — Backdating a treasury LedgerEntry strands venture CPTR banking_transfers — cursor never re-delivers, create_or_find_by! never updates
- [duplicate wire debit mismatch](duplicate-wire-debit-mismatch.md) — Balance-check mismatch class — a completed outgoing wire gets a SECOND CA→wire WITHDRAWAL ledger entry
- [flowdash treasury ca creation](flowdash-treasury-ca-creation.md) — What it takes to create treasury CustomerAccounts from Flowdash (scoping findings, 2026-06-27)
- [funds migration autoforward stranding](funds-migration-autoforward-stranding.md) — Treasury balance-mismatch failure mode — auto-forwarder strands a deposit on the active sub-account after a bank migration
- [ikyam incident orphan zeroings](ikyam-incident-orphan-zeroings.md) — Upekkha/IKYAM Aug-2026 incident — rejected wire return booked twice; three orphan zeroings are the whole audit/revised gap.
- [incoming wire manual return gotchas](incoming-wire-manual-return-gotchas.md) — Treasury manual IncomingWire return — transition_to! does NOT fire the Prophet event
- [incoming wire reassignment stale sub](incoming-wire-reassignment-stale-sub.md) — Reassigning an IncomingWire's CustomerAccount does NOT repoint sub_account_id; transfer! self-heals via original_sub_account (a real Transfer V2)
- [incoming wire return automation gap](incoming-wire-return-automation-gap.md) — Why Treasury can't auto-return an IncomingWire when TP returns it — TP pushes no incoming-return event
- [ivc phantom overcredit migration](ivc-phantom-overcredit-migration.md) — Balance-check overcredit on IVC shared-account FX vehicles
- [missing card txn overcredit](missing-card-txn-overcredit.md) — Balance-check overcredit class — TP settles debit-card withdrawals that never post to Treasury's ledger
- [mmf balance check multiprovider](mmf-balance-check-multiprovider.md) — MMF balance-check monitoring (BANK-1486, PR #8067) generalized to multiple concurrent providers; the coherence axis + the one deferred APEX follow-up.
- [mmf design doc arti](mmf-design-doc-arti.md) — The canonical MMF architecture design doc lives in Arti (not the treasury repo); + the ProviderPlan→Adapters seam rename.
- [mmf frec deposit account routing collision](mmf-frec-deposit-account-routing-collision.md) — Frec deposit accounts are matched/deduped by routing last-4 only
- [mmf sell fee skip regression](mmf-sell-fee-skip-regression.md) — MMF balance-check divergences from PR #8038 skipping the MMF_SELL_FEES sweep → $45 phantom cash
- [mmf yield dedup keys](mmf-yield-dedup-keys.md) — MMF yield receipts carry TWO unique dedup keys; the provider-neutral one is a real DB index, and dropping the Frec one loses restatement dedup
- [money to money is dollars not cents](money-to-money-is-dollars-not-cents.md) — Integer#to_money means DOLLARS; Money.new(int) means CENTS — mixing them silently breaks guard assertions in prod scripts
- [network transfer destination credit lag](network-transfer-destination-credit-lag.md) — TP NetworkTransfers credit the destination bank days before TP status leaves `processing`
- [OP stuck in requested](op-flowdash-stage-and-outbox-drop.md) — two bugs: the wire stage mapping never advances requested→created, and an outbox drop loses the event.
- [payment trace identifiers two stores](payment-trace-identifiers-two-stores.md) — Wire IMAD/OMAD and ACH trace numbers live in TWO treasury stores; the Treasury-side column is a lossy mirror
- [plaid sync balance 500 attribution](plaid-sync-balance-500-attribution.md) — How to find the affected CustomerAccount for a treasury Plaid sync_transactions balance-500 trace (item_id is never logged)
- [svb over 1m wire forward 8611](svb-over-1m-wire-forward-8611.md) — PR #8611/#8126 chunk >$1M SVB→non-SVB incoming-wire forwards into ACH; fixes ROUTING only
- [tp returned wire double recognition](tp-returned-wire-double-recognition.md) — Treasury Prime returned wires get double-recognized — the rejection books a synthetic return and no dedupe exists against the real IncomingWire.
- [treasury api error http mapping](treasury-api-error-http-mapping.md) — How treasury's legacy REST Api::Controller maps exceptions to HTTP status; Transfer::CreationError's two raise categories
- [treasury bny 1044 cleanup](treasury-bny-1044-cleanup.md) — $10.44 BNY test-sub cleanup (incident 2026-08-04): PR #8784 one-shot MT with two chained V2 transfers Piermont 490735 → closed BNY 501802 → GHB
- [treasury cancelled revision transfer audit gap](treasury-cancelled-revision-transfer-audit-gap.md) — Treasury audit-vs-revised balance mismatch failure mode
- [treasury countries enum binread flake](treasury-countries-enum-binread-flake.md) — FIXED and MERGED to main 2026-07-31 (PR #8405 / BANK-1726, commit 66cdbe6ad)
- [cron schedules live in Temporal, NOT cdk8s](treasury-cron-schedules-cdk8s.md) — moved 2026-09-02 to lib/temporal/schedules/registry.rb; the cdk8s arrays are empty and a stale checkout will mislead you.
- [treasury enum value ci and rollback](treasury-enum-value-ci-and-rollback.md) — Adding a T::Enum value in treasury needs `make graphql` + `make rbi` (CI blockers rspec/srb can't see)
- [treasury fast ach credit availability](treasury-fast-ach-credit-availability.md) — ACH-pull accelerated funds availability — gated on EAA reliability + $25k global cap; the $10M trusted seed is clamped/inert.
- [treasury ledger resume double emit gap](treasury-ledger-resume-double-emit-gap.md) — Resuming treasury's merged ledger from an entry is lossy: double-emitted rows share one keyset cursor, so the sibling leg is dropped.
- [treasury link existing increase ca](treasury-link-existing-increase-ca.md) — How to link a pre-existing Increase account to a Treasury CustomerAccount (INTERNAL_FINANCE etc.) — no service path exists
- [treasury mgmt fee cross instance](treasury-mgmt-fee-cross-instance.md) — Management-fee releases are cross-INSTANCE transfers (main→management_company)
- [treasury mmf sell completion validation](treasury-mmf-sell-completion-validation.md) — Transfer can't enter Completed without initiating_payment_processor_transfer_id; PR #8378 removed the only writer on the MMF sell path (2026-07-28)
- [treasury nova event bridge](treasury-nova-event-bridge.md) — Prophet/NATS treasury→nova event bridge — architecture, service names, and how to scope its exceptions vs the loud non-bridge noise.
- [treasury outgoing transfers resolver flake](treasury-outgoing-transfers-resolver-flake.md) — Known order-dependent flaky treasury spec: OutgoingTransfersResolver CA-scoped test; bare source_id collides across wire/payment tables
- [treasury point in time balances created at](treasury-point-in-time-balances-created-at.md) — Treasury as-of balances filter on created_at and there is no effective-date column, so a late correction never reconciles for a past close date.
- [treasury prod console access](treasury-prod-console-access.md) — How to run prod Rails console queries myself via the `al console` CLI (kubectl consoles) instead of handing Kevin scripts
- [treasury prophet datadog](treasury-prophet-datadog.md) — Datadog query facts for treasury Prophet APM observability + the Banking dashboard
- [treasury repair task gotchas](treasury-repair-task-gotchas.md) — Recurring traps when writing a Maintenance repair task that destroys prod ledger rows: dry_run proves nothing about writes
- [treasury schema load landmine](treasury-schema-load-landmine.md) — treasury CI does db:schema:load then db:migrate
- [treasury sorbet sigs not runtime guards](treasury-sorbet-sigs-not-runtime-guards.md) — In treasury, a non-nilable Sorbet sig does NOT raise at runtime in prod and is skipped entirely in test — never treat a clean typecheck as a nil guard
- [treasury spec tasks maintenance flake](treasury-spec-tasks-maintenance-flake.md) — spec/tasks/maintenance/create_*_missing_card_transactions_task_spec.rb assert UNSCOPED global LedgerEntry counts
- [treasury stale returned wire balance check](treasury-stale-returned-wire-balance-check.md) — Treasury balance-check failure mode — an IncomingWire marked returned without its outbound leg holds a ledger balance forever and inflates the check
- [treasury statement generate fetch race](treasury-statement-generate-fetch-race.md) — TP monthly-statement download errors the FIRST pull of a fresh month — generate-then-immediately-fetch race, no polling
- [treasury subaccount retry heal](treasury-subaccount-retry-heal.md) — Treasury stranded-account (no sub-account) reactive heal via RetryService on next transfer; why the FBO-create partial-creation edge is NOT ticketed
- [treasury three balance functions](treasury-three-balance-functions.md) — Treasury has three different balance functions per customer account that return different numbers; only full_internal_balance feeds the balance check
- [treasury worktree dev loop](treasury-worktree-dev-loop.md) — How to run treasury specs/sorbet/rubocop in an isolated git worktree, and the venture-console access limit
- [unprocessed ach return overcredit](unprocessed-ach-return-overcredit.md) — Balance-check overcredit failure mode — bank returns an incoming ACH but Treasury never fires IncomingWire#return!
- [upekkha oncore reconciliation state](upekkha-oncore-reconciliation-state.md) — Handed to flint 2026-08-31 — Upekkha on-core audit/sub-account divergence: what's fixed, what's open, and two repairs proven harmful

## Added
- [feedback packwerk literal vs constant](feedback-packwerk-literal-vs-constant.md) — A review nit to swap a string literal for a cross-package constant ref can break Packwerk strict mode — verify before adopting
- [INC-5462 Piermont intl wire routing](inc-5462-piermont-intl-wire-routing.md) — both ABAs are real, do NOT collapse. #8515 fixes the treasury PDF ONLY; nova is fixed in #9436 (approved, unmerged); venture wire_manual.rb STILL collapses — that is the surface the reporter saw.
- [ledger recon measure every account](ledger-recon-measure-every-account.md) — Ledger reconciliation target sets must include every account the plan writes, especially GlobalAccounts; GA#26 is the SVB sync anchor.
- [rake spec double load tasks](rake-spec-double-load-tasks.md) — Two rspec files each calling Rails.application.load_tasks makes every rake task body run twice — guard the load
- [spec neighborhood must include tasks](spec-neighborhood-must-include-tasks.md) — When a change guards a service method, hand-picked spec paths miss spec/tasks/
- [treasury mock ipseity not mock entity api](treasury-mock-ipseity-not-mock-entity-api.md) — In treasury the entity-API mock var is MOCK_IPSEITY, not MOCK_ENTITY_API — the CLAUDE.md pre-push `unset MOCK_ENTITY_API` is a silent no-op there
- [APEX spike — SUPERSEDED](apex-mmf-discovery.md) — thin duplicate of bank-1665-apex-mmf-discovery. The 2nd-provider project pivoted APEX→Interchange on 2026-08-14; keep only for the AscendOS spec location.
- [dibs aba has no institution id](dibs-aba-has-no-institution-id.md) — DIBS dibs_aba_routing_records has NO institution id; only stable key is routing_number, RSSD is the real answer
- [inc 5437 real bug is treasury](inc-5437-real-bug-is-treasury.md) — INC-5437 was misdiagnosed as ipseity and a fix was merged then reverted; the real bug is live in treasury Api::AlloysController
- [treasury conductor worktree notes](treasury-conductor-worktree-notes.md) — Treasury worktree notes salvaged from the conductor vancouver scope; its make graphql claim was wrong
- [venture 33053 op routing half](venture-33053-op-routing-half.md) — The date-independent half of venture #33053 is treasury's: OP routing hardcodes the category and ignores the caller
