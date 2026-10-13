# Project Memory Index

Hooks answer "open this file?" — detail lives in the file, not here.

## How Kevin wants me to work

`~/.claude/CLAUDE.md` now carries the short form of these rules so they load in every session,
including outside this cwd. It carries the directive only — the operational detail (endpoints,
recipes, the failure that produced the rule) stays in these files, so keep the pointers.

- [terse comments + alert text](kevin-terse-code-comments-and-alert-messages.md) — incl. Datadog monitor text. Flagged 3×.
- [concise ops replies](kevin-prefers-concise-ops-replies.md) — 1-4 lines; a big finding gets a *shorter* reply.
- [plain English](kevin-prose-plain-english.md) — low jargon; tables aren't default structure.
- [no AI prose](feedback-plain-english-no-ai-prose.md) — the tell-list. Also a Linear `lead:`/`assignee:` null trap.
- [concise recommendations](feedback-concise-recommendations.md) — 1-3 sentences, then stop.
- [don't overclaim in comments](feedback-draft-comments-last.md) — write them last, against final code.
- [reply + resolve threads](pr-feedback-thread-reply-and-resolve.md) — BOTS only; human threads are draft-only. Resolve is GraphQL-only; your reply echoes back.
- [resolve AI review threads](feedback-resolve-ai-review-threads.md) — reply AND resolve (Cursor/Bugbot).
- [check human PR reviews](feedback-check-human-pr-reviews.md) — three endpoints; APPROVED can still demand changes.
- [repair data, not invariants](feedback-repair-data-not-invariants.md) — grep every writer first.
- [plan the backfill](feedback-backfill-with-ledger-changes.md) — deploy order and idempotency under live writes.
- [question the shared constant](feedback-question-the-shared-constant-premise.md) — sharing can be worse than duplication.
- [verify premise first](verify-domain-premise-before-crediting.md) — external research and cite it; grep isn't verification.
- [yewon = he/him](yewon-lee-pronouns.md) — never infer pronouns from a name; default they/them.
- [read venture AGENTS.md](venture-read-agents-md-best-practices.md) — before editing venture; legacy files mislead.
- [use nova's worktree-dev skill](nova-use-worktree-dev-skill.md) — bare `git worktree add` skips infra/ports/BASE_URL, so Playwright tasks become impossible.
- [nova comment policy](nova-comment-policy-review-gap.md) — strict; police it in nova reviews too.
- [review gate playbook](review-gate-playbook.md) — hub for all 19 gate notes: counting, briefs, fix verification, mutation, declines, handoff, baseline.
- [don't reply on PRs when it's informational](feedback_no_pr_commenting.md) — answer Kevin, don't post on his behalf.
- [broaden review on a repeat pattern](feedback_broaden_review_for_repeat_pattern.md) — if an external reviewer catches the same root cause twice, sweep for the rest yourself.
- [inventory call sites for a new primitive](feedback_pr_call_site_inventory.md) — a helper added without migrating existing callers is half a change.
- [audit over completeness](feedback_audit_over_completeness.md) — when merging multiple sources into one record, keep the provenance auditable.
- [use a worktree for other branches](feedback_use_worktree_for_other_branches.md) — never check another branch out over the shared checkout.
- [post approved plans to Linear](feedback_post_plan_to_linear.md) — once a plan is approved and the branch maps to an issue.
- [give plan files real paths](feedback_plan_file_paths.md) — the ExitPlanMode preview is hard to scan when the file is large.
- [al console file transfer](feedback_al_console_file_transfer.md) — how to run a local script inside Kevin's open `al console`, or pull a file back out.
- [never poll `al console` in a loop](feedback_no_long_polling_al_console.md) — 341 invocations, ~62 auth prompts overnight; cap it, exit on first failure, kill watchers before signing off.
- [`al config set` eats blank lines](feedback_al_config_set_strips_blank_lines.md) — it silently strips adjacent blank lines in YAML configtool files; restore before committing.

### Bridge mechanics
- [the bridge is Slack, not Discord](bridge-is-slack.md) — the plugin is labelled `discord`; the human-facing side is Slack and Slack threads work.
- [the bridge only delivers the DM](bridge-only-delivers-dm.md) — only `D0BE3RB4Y00` arrives as inbound; other channels do not.
- [reply tool only](always-reply-via-tool.md) — transcript text never reaches Kevin; only the reply tool does.
- [chat_id = thread](reply-chat-id-must-be-thread.md) — copy it from the inbound tag, never a message_id; a bare chat_id may be a stripped thread, so verify.
- [reply param is `text`](reply-tool-param-is-text.md) — not `message`.
- [no AskUserQuestion here](no-askuserquestion-on-bridge.md) — nor ExitPlanMode; the bridge carries only the reply tool.
- [spawn lines are notifications](main-session-spawn-notifications.md) — and main CAN reach sub-sessions via ListAgents + SendMessage. `build-wt:` no longer exists.
- [post in the actual thread](feedback-post-in-the-actual-thread.md) — offering instead of doing = stalling.
- [bridge outbound can die](bridge-outbound-dead-curl-fallback.md) — `sent` lies; curl fallback recipe.
- [pr-watch pings are unreliable](pr-watch-phantom-pings.md) — phantom empties, missed reviews, and it echoes your own reply back as new feedback.

### Repo & environment hazards
- [every shared checkout is stale](stale-shared-checkouts-are-the-norm.md) — nova too, not just treasury; fetch and read `origin/main:<path>` before citing any file:line.
- [shared checkout isn't isolated](shared-checkout-worktree-isolation.md) — concurrent sessions share it; commit carefully.
- [agent-memory's tree is production](agent-memory-worktree-is-production.md) — a checkout there changes the LIVE CLAUDE.md rules and memory store; it is always dirty by design.
- [another session can tear down your worktree](another-session-can-tear-down-your-worktree.md) — only the branch ref survives; recovery recipe, and point subagents at `git show <branch>:<path>`.
- [bash cwd persists](bash-cwd-persists-across-calls.md) — one `cd` silently redirects later calls.
- [bot commit signing is flaky](bot-session-cannot-sign-commits.md) — SSH signing from this session is intermittent.
- [worktree spawn times out on nova](hydra-worktree-add-15s-timeout.md) — 15s cap on `git worktree add`; cold nova fails and strands a dir + `wt/` branch. Pre-create instead.
- [husky hooks die in a fresh worktree](husky-hooks-fail-in-fresh-worktree.md) — `.husky/_/` is gitignored, so commit and push fail; don't `pnpm install` to fix.
- [a daemon restart orphans threads](hydra-restart-orphans-threads.md) — threads fall back to main while health says OK; grep `mappedSession=none`, fix with `respawn`.

## Tooling
- [Notion: fetch is the only proof](notion-mcp-verification-and-stale-client.md) — search and failed-write probes give false negatives; desktop shows deleted blocks.
- [CI failure via Chrome](ci-failure-via-chrome-skill.md) — pull a red build's failing example when there is no CI token.
- [Linear has no saved-view tool](linear-no-saved-view-tool.md) — use a shared issue label as the filterable set.
- [1Password tmux prompts](onepassword-cli-prompts.md) — why "Allow tmux to get CLI access" recurs, and how to stop it.
- [a slept laptop skews test runs](sleep-interrupted-test-runs.md) — wall clock far over normal means sleep, not a hang.
- [voice transcription](voice-message-transcription.md) — local hydra sidecar, nothing leaves the machine.
- [RTL PR bump](rtl-pr-bump-automation.md) — 12h unreviewed → "bump". The cloud env has no `gh`.
- [chaos testing](chaos-testing-devin-playbooks.md) — 2 Devin playbooks, not CI; skips PRs with no `frontend/` files.
- [arti needs charset meta](arti-html-needs-charset-meta.md) — arti serves HTML raw; omit it and you get mojibake.
- [arti chunked upload](arti-chunked-upload-large-html.md) — ~11KB appends, `separator:""`, verify via size_bytes.
- [local whisper transcribe](audio-transcription-uvx-whisper.md) — `uvx --from mlx-whisper`; ask before running.

## Other scopes

**Read the matching scope before starting work on any repo named below.** Nothing loads it for you: a
scope's index loads only when cwd *is* that repo, and sessions spawned here run at the umbrella cwd,
while worktree sessions have no memory directory at all. So this is the primary path, not a fallback.

```sh
cat ~/agent-memory/scopes/<name>/MEMORY.md
ls ~/agent-memory/scopes/*/*<memory-name>.md   # a [[wikilink]] that resolves in no scope is in another
```

Keep the leading `*`. Many filenames carry a `feedback_` / `project_` / `reference_` prefix that the
wikilink omits, and without the wildcard 38 of the 280 link targets look missing when they are not.
About 17 genuinely resolve nowhere — those are notes-to-self for memories never written.

| scope | holds |
|---|---|
| `Users-kevin-RubymineProjects-treasury` | treasury and banking, balance checks, MMF, incidents (168) |
| `Users-kevin-RubymineProjects-nova` | nova, LP-wallet matchmaking, entity migration (93) |
| `Users-kevin-RubymineProjects-ipseity` | ipseity and KYC (16) |
| `Users-kevin-RubymineProjects-venture` | venture (21) |
| `Users-kevin-RubymineProjects-hydra` | hydra daemon internals and session mechanics (35) |
| `Users-kevin-RubymineProjects-usvc` | usvc (2) |
| `Users-kevin-RubymineProjects-angellist-user-mapping` | the `angellist_user_mapping` gem, Alloy DRI mapping (2) |
| `Users-kevin` | home-directory scope: personas, machine setup (10) |

`[[wikilinks]]` inside these files often point across scopes now — 26 of the umbrella's own targets
live elsewhere. Resolve one with the `ls` glob above rather than concluding it is missing.

- [claude md ancestor loading rules](claude-md-ancestor-loading-rules.md) — an ancestor .claude/ contributes CLAUDE.md, agents/ and skills/, but not its @imports.

## Added
- [feedback external writing style](feedback_external_writing_style.md) — Kevin's house voice for all external-facing writing (PRs, Linear, artifacts, code comments, review replies)
- [feedback gt modify all](feedback_gt_modify_all.md) — gt modify -a / --all behaves like git add -A and pulls untracked files into the amend; stage by path instead
- [feedback reduce revision churn](feedback_reduce_revision_churn.md) — How to cut the number of revision rounds Kevin needs on proposed code/wording
- [reference prophet rails8 ref](reference_prophet_rails8_ref.md) — The prophet git-gem ref that unblocks Rails 8 across AngelList consumers (ipseity/treasury/venture)
- [feedback ci bisect verify against green](feedback_ci_bisect_verify_against_green.md) — Before blaming a commit for a CI regression, verify the offending code is absent from currently-green builds
- [feedback constants at top](feedback_constants-at-top.md) — Constants must be defined at top of class, before method definitions — never inside class << self or after private
- [status update each step](feedback_status_update_each_step.md) — 1-2 line reply after every finished step on long runs.
- [feedback eyeballs ack](feedback_eyeballs-ack.md) — ack every inbound message fast; 👀 `react` is a NO-OP on Slack, so send a one-line reply instead
- [link Linear issues in comments](feedback_link_linear_issues_in_comments.md) — in PR comments and prose, hyperlink Linear IDs to their URL.
- [never checkout over uncommitted work](feedback_never_checkout_over_uncommitted_work.md) — commit first; `git checkout <ref> -- <paths>` is unrecoverable.
- [feedback preserve existing comments](feedback_preserve-existing-comments.md) — Do not delete pre-existing comments when refactoring — only change code you were asked to change
- [verify against prod](feedback_prod-query-local-verify.md) — simulate maintenance-task effects with prod queries via al console, not reasoning alone.
- [signed commit: check the raw object](feedback_signed-commit-verify-raw-object.md) — `%G?` says N without an allowedSignersFile even when signed.
- [feedback verify localhost e2e](feedback_verify-localhost-e2e.md) — Always verify localhost page loads end-to-end before sharing the URL with Kevin
- [merged contract drift](reference_merged_contract_drift_hides_in_branch_ref.md) — diff the MERGED cross-repo artifact, not the source branch ref (it advances).
- [shell script review blind spots](shell-script-review-blind-spots.md) — What shell-script review misses: partial-state checks, docker compose v1 vs v2, and // true hiding side effects
- [verify fixture assumptions](feedback_verify_fixture_assumptions.md) — a live record picked off the top of a list is not a controlled fixture; check its properties first.

## Unfiled
- [Daedalus](project_daedalus.md) — rule-change scorer; angellist/daedalus, steps 1-4 built 10/10; back-test confounded by model+TTL switch; HANDOFF in review-findings/daedalus/design.
- [mock env vars differ by repo](mock-env-vars-differ-by-repo.md) — `unset MOCK_ENTITY_API` is a no-op everywhere; and `env -u` vs `VAR=` invert between treasury and venture.
- [a test fixture can poison the shared git config](test-fixture-git-init-poisons-shared-config.md) — `git init .` after a failed `cd`; tell: `committer t <t@t>`.
- [zsh `\u` only expands in `$'…'`](zsh-unicode-escape-only-in-ansi-c-quotes.md) — a "non-ASCII" fixture becomes a backslash name, which git quotes regardless of `core.quotePath`.
- [zsh eats `:a` in `git show "$B:app/…"`](zsh-eats-colon-a-in-git-show-base-path.md) — brace it as `"${B}:app/…"`; CLAUDE.md's own recipe breaks on any path starting with a modifier letter.
- [nova savepoint tests need real failing SQL](nova-savepoint-tests-need-real-failing-sql.md) — a mocked err-Result never aborts the tx; inject `SELECT 1 / 0`.
- [CPTR sync backdate trap](cptr-banking-transfer-sync-backdate-trap.md) — cursor never re-delivers a backdated LE; 8809 ran 9/17, Upekkha venture row b986841e still needs the in-place date patch
- [verify new assertions can fail](feedback_verify_new_assertions_can_fail.md) — mutation-test what you add; and a mutation that silently fails to APPLY reads as a pass.
- [PR links auto-watch on the bridge](bridge-pr-links-auto-watch.md) — a reply full of PR links subscribes you to all of them; unwatch after.
- [slack fallback echoes your own sends](bridge-slack-fallback-echoes-own-messages.md) — the echo trips the reply watchdog; match message_id against your send.
- [on-core unposted-credit remediation](project_oncore_unposted_credit_remediation.md) — #8981 merged; BonBillo done; **CA 351233 phase 2 still outstanding**, waiting on TP to post.
- [TODO: Jev effort routing](project_todo_jev_effort_routing.md) — PARKED 9/29; per-prompt `/effort` via Jev classifier; first measure whether `/effort` resets cache.
- [TODO: TransfersTable SVB processor flip](project_todo_transfers_table_svb_processor_flip.md) — UI shows processors under the wrong bank; data is right. Own PR.
- [TODO: dedup-port recipient-org artifact](project_todo_dedup_port_recipient_org_artifact.md) — MAPA/Thunderclap ported wallets unreachable; write the artifact with org links + fix sites.
- [TODO: incoming-wire ledger hides requested entries](project_todo_incoming_wire_ledger_requested_entries.md) — return leg and forward invisible on the wire page. Own PR.
- [gt submit on a stale trunk mis-titles the PR](gt-submit-stale-trunk-wrong-pr-title.md) — `--ignore-out-of-sync-trunk` mis-titles; re-check and PATCH.
- [session token anatomy](project_session_token_anatomy.md) — artifact v2 + scripts; expiry rewrites 31% of main cost; subagent usage-row trap.
- [respawn inherits model](hydra-respawn-inherits-model.md) — respawn/resume reuse the dead session's model, not HYDRA_MODEL; switch in-pane with `/model opus[1m]`.
- [who-did-it in nova prod](nova-who-did-it-datadog-trail.md) — GraphQL op logs have trueUser+variables; RUM has is_impersonating; recipientStartedAt fires on any view.
- [stash push no-op applies a foreign stash](stash-push-noop-applies-foreign-stash.md) — empty SHA pulls another session's WIP; mutation-check with cp.
- [venture worktree frontend install](venture-fresh-worktree-frontend-install.md) — `GITHUB_TOKEN_PKG=$(gh auth token)`; main checkout node_modules are stale.
- [treasury specs via sibling container](treasury-specs-sibling-container.md) — borrow another worktree's image; revert the Gemfile.lock reorder.
- [context link ≠ post target](feedback_context_link_is_not_post_target.md) — a Slack link shared "for context" is not a go-ahead to post as Kevin; draft in his voice first
- [TP idempotency replay is undefined](treasury-tp-idempotency-replay-undefined.md) — docs never say what a replay RETURNS, and keys die at 7 days; never plan a recovery on "just re-POST it".
- ["handoff:" is a directive](feedback_handoff_prefix_is_directive.md) — write the handoff file and call the handoff tool immediately; the rest of the message goes into Next action
- [one issue per follow-up](feedback_one_issue_per_item.md) — "track these in a gh issue" still means one issue each, cross-linked.
- [no gate for memory prose](feedback_no_gate_for_memory_prose.md) — agent-memory prose-only PRs skip the review gate; Kevin, 10/12
- [rules use paths:, not globs:](claude-rules-paths-frontmatter.md) — globs: ignored; nested AGENTS.md auto-loads; user-level rules need a **/ prefix under hydra
