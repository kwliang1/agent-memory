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
- [attribution + verify the base](review-loop-attribution-discipline.md) — two rules; `git merge-base`, never a pinned SHA.
- [serialize mutation agents](feedback-serialize-mutation-agents.md) — or give each its own worktree.
- [repair data, not invariants](feedback-repair-data-not-invariants.md) — grep every writer first.
- [plan the backfill](feedback-backfill-with-ledger-changes.md) — deploy order and idempotency under live writes.
- [question the shared constant](feedback-question-the-shared-constant-premise.md) — sharing can be worse than duplication.
- [verify premise first](verify-domain-premise-before-crediting.md) — external research and cite it; grep isn't verification.
- [yewon = he/him](yewon-lee-pronouns.md) — never infer pronouns from a name; default they/them.
- [read venture AGENTS.md](venture-read-agents-md-best-practices.md) — before editing venture; legacy files mislead.
- [nova comment policy](nova-comment-policy-review-gap.md) — strict; police it in nova reviews too.
- [the gate is 2 clean rounds, not 3](feedback_review_gate_count.md) — stop at the second "no concerns"; don't add a defensive round.
- [don't reply on PRs when it's informational](feedback_no_pr_commenting.md) — answer Kevin, don't post on his behalf.
- [broaden review on a repeat pattern](feedback_broaden_review_for_repeat_pattern.md) — if an external reviewer catches the same root cause twice, sweep for the rest yourself.
- [inventory call sites for a new primitive](feedback_pr_call_site_inventory.md) — a helper added without migrating existing callers is half a change.
- [audit over completeness](feedback_audit_over_completeness.md) — when merging multiple sources into one record, keep the provenance auditable.
- [use a worktree for other branches](feedback_use_worktree_for_other_branches.md) — never check another branch out over the shared checkout.
- [post approved plans to Linear](feedback_post_plan_to_linear.md) — once a plan is approved and the branch maps to an issue.
- [give plan files real paths](feedback_plan_file_paths.md) — the ExitPlanMode preview is hard to scan when the file is large.
- [al console file transfer](feedback_al_console_file_transfer.md) — how to run a local script inside Kevin's open `al console`, or pull a file back out.
- [`al config set` eats blank lines](feedback_al_config_set_strips_blank_lines.md) — it silently strips adjacent blank lines in YAML configtool files; restore before committing.

### Bridge mechanics
- [the bridge is Slack, not Discord](bridge-is-slack.md) — the plugin is labelled `discord`; the human-facing side is Slack and Slack threads work.
- [the bridge only delivers the DM](bridge-only-delivers-dm.md) — only `D0BE3RB4Y00` arrives as inbound; other channels do not.
- [reply tool only](always-reply-via-tool.md) — transcript text never reaches Kevin; only the reply tool does.
- [chat_id = thread](reply-chat-id-must-be-thread.md) — take it from the inbound `<channel chat_id="...">`; never a message_id.
- [reply param is `text`](reply-tool-param-is-text.md) — not `message`.
- [no AskUserQuestion here](no-askuserquestion-on-bridge.md) — nor ExitPlanMode; the bridge carries only the reply tool.
- [spawn lines are notifications](main-session-spawn-notifications.md) — and main CAN reach sub-sessions via ListAgents + SendMessage. `build-wt:` no longer exists.
- [post in the actual thread](feedback-post-in-the-actual-thread.md) — offering instead of doing = stalling.
- [bridge outbound can die](bridge-outbound-dead-curl-fallback.md) — `sent` lies; curl fallback recipe.
- [pr-watch pings are unreliable](pr-watch-phantom-pings.md) — phantom empties, missed reviews, and it echoes your own reply back as new feedback.

### Repo & environment hazards
- [shared checkout isn't isolated](shared-checkout-worktree-isolation.md) — concurrent sessions share it; commit carefully.
- [bash cwd persists](bash-cwd-persists-across-calls.md) — one `cd` silently redirects later calls.
- [bot commit signing is flaky](bot-session-cannot-sign-commits.md) — SSH signing from this session is intermittent.

## Tooling
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

- [claude md ancestor loading rules](claude-md-ancestor-loading-rules.md) — VERIFIED: an ancestor .claude/ dir contributes CLAUDE.md body + agents/ + skills/ to any session under it, but its @imports are NOT followed

## Added
- [feedback external writing style](feedback_external_writing_style.md) — Kevin's house voice for all external-facing writing (PRs, Linear, artifacts, code comments, review replies)
- [feedback gt modify all](feedback_gt_modify_all.md) — gt modify -a / --all behaves like git add -A and pulls untracked files into the amend; stage by path instead
- [feedback reduce revision churn](feedback_reduce_revision_churn.md) — How to cut the number of revision rounds Kevin needs on proposed code/wording
- [feedback use graphite](feedback_use_graphite.md) — Always use gt (Graphite) commands instead of raw git/gh for branching, pushing, and PR creation
- [no reply human review without approval](no-reply-human-review-without-approval.md) — Never reply to human PR review comments without Kevin's explicit approval first — report them to Kevin and wait.
- [reference prophet rails8 ref](reference_prophet_rails8_ref.md) — The prophet git-gem ref that unblocks Rails 8 across AngelList consumers (ipseity/treasury/venture)
- [feedback ai feedback before review gates](feedback_ai_feedback_before_review_gates.md) — Workflow order — address PR AI-bot feedback (Cursor Bugbot, Devin) before running the pre-push review-agent gate
- [feedback be concise with kevin](feedback_be-concise-with-kevin.md) — Kevin finds long explanations tedious — lead with the answer, keep replies short
- [feedback buildwt clean round count](feedback_buildwt_clean_round_count.md) — In build-wt spawns, the number Kevin passes is the required count of SUCCESSIVE CLEAN review rounds, not a round ceiling
- [feedback ci bisect verify against green](feedback_ci_bisect_verify_against_green.md) — Before blaming a commit for a CI regression, verify the offending code is absent from currently-green builds
- [feedback constants at top](feedback_constants-at-top.md) — Constants must be defined at top of class, before method definitions — never inside class << self or after private
- [feedback eyeballs ack](feedback_eyeballs-ack.md) — React with 👀 to ack a Slack/Discord message the moment you pick it up
- [feedback freeze tree during review rounds](feedback_freeze_tree_during_review_rounds.md) — Commit and then freeze the tree while pre-push review agents run; editing under them wastes a round
- [feedback link linear issues in comments](feedback_link_linear_issues_in_comments.md) — In GitHub PR comments/replies (and similar prose), hyperlink Linear issue references to their URL instead of a bare identifier
- [feedback minimal change in review gate](feedback_minimal-change-in-review-gate.md) — In a review gate, fix only what the finding requires — reaching further introduced 4 regressions in one session
- [feedback mutation agents corrupt worktree](feedback_mutation-agents-corrupt-worktree.md) — Review agents doing mutation testing revert/edit source in the SHARED worktree, corrupting the working tree mid-gate
- [feedback never checkout over uncommitted work](feedback_never_checkout_over_uncommitted_work.md) — Commit before any control experiment; `git checkout <ref> -- <paths>` destroys uncommitted work with no stash entry to recover from
- [feedback preserve existing comments](feedback_preserve-existing-comments.md) — Do not delete pre-existing comments when refactoring — only change code you were asked to change
- [feedback prod query local verify](feedback_prod-query-local-verify.md) — When verifying maintenance task logic, query prod via al console to simulate effects rather than only trusting analytical reasoning
- [feedback review gate catches](feedback_review-gate-catches.md) — Review agent settings -- opus model, high effort; address Devin/Cursor feedback; reply to PR threads with fix links
- [feedback review gate five reviewers](feedback_review-gate-five-reviewers.md) — Kevin raised the pre-push review gate from 3 to 5 parallel reviewers per round (2026-07-08)
- [feedback signed commit verify raw object](feedback_signed-commit-verify-raw-object.md) — git %G? returns N (false negative) with no allowedSignersFile even when the commit IS signed — check the raw object, not %G?
- [feedback terse inline comments](feedback_terse-inline-comments.md) — Kevin wants inline code comments TERSE — one short line, rationale goes in the PR/commit, not the source
- [feedback verify localhost e2e](feedback_verify-localhost-e2e.md) — Always verify localhost page loads end-to-end before sharing the URL with Kevin
- [reference merged contract drift hides in branch ref](reference_merged_contract_drift_hides_in_branch_ref.md) — Verifying a client against a just-merged cross-repo contract — diff the MERGED artifact directly, not the source branch ref (it advances too)
- [shell script review blind spots](shell-script-review-blind-spots.md) — What shell-script review misses: partial-state checks, docker compose v1 vs v2, and // true hiding side effects

## Unfiled
- [mock env vars differ by repo](mock-env-vars-differ-by-repo.md) — CLAUDE.md's pre-push `unset MOCK_ENTITY_API` is a no-op in every repo that names it — the real mock vars differ per repo <!-- hook from frontmatter, unverified -->
