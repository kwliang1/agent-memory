# Memory Index

- [Hydra dictation PR](hydra-dictation-pr.md) — fork PR #1 finished 2026-07-03; shared-session/park design; fork-main push pending; bun test env convention
- [Hydra Slack setup](hydra-slack-setup.md) — local Slack bridge config, auth + channels-gate gotchas
- [Hydra session resurrection](hydra-session-resurrection.md) — recovering spawned sessions after tmux kill-server; re-attach-only persistence, crash-loop + parked-bot gotchas
- [Hydra rebase follow-ups](hydra-rebase-followups.md) — TODOs on kevinliang/no-spawn-notify-main (rebased 2026-07-01, unpushed): dedup slack self-heal, .tool-versions, resurrect persona
- [Hydra parked-main recovery](hydra-parked-main-recovery.md) — TODO/design: auto-detect + recover parked slack-byte, stop losing the stuck input-buffer message on restart
- [Hydra reboot recovery facts](hydra-reboot-recovery-facts.md) — VERIFIED current-code: dead workers survive reboot w/ artifacts; link-loss = respawn killSession; slack-byte fail = legacy watchdog/.claude-byte split; reuse recover cascade
- [Hydra 1Password prompt fix](hydra-1password-prompt-fix.md) — RESOLVED: tmux CLI-access prompt storm = treasury Makefile op reads; ~/.zshenv DAEMON_SOCK-gated DD stub; SA token file is a dormant placeholder
- [Hydra codex setup](hydra-codex-setup.md) — codex engine needs bun>=1.3.14 (ws shim); `codex login status` lies, check logs_2.sqlite; auth.json refresh tokens are single-use
- [Hydra pane-probe login flap](hydra-pane-probe-login-flap.md) — PR #310 (unmerged, needs `hydra restart slack`): live-screen gate + latch stop login-success/expiring re-notify spam
- [Hydra shared lifecycle helpers](hydra-shared-lifecycle-helpers.md) — tryResume/doSpawnSession/killSession shared by manual thread commands AND recovery; gate recovery-only changes behind a flag
- [Hydra worktree name divergence](hydra-worktree-name-divergence.md) — recovered sessions get fresh tmuxName but keep old worktreeBranch; branch-protection must parse worktreeBranch not tmuxName
- [Hydra Slack API facts](hydra-slack-api-facts.md) — live-verified conversations.history/replies lookup semantics; docs are wrong in two directions
- [Hydra attachment follow-ups](hydra-attachment-followups.md) — #352 merge-READY (not merged), needs a daemon restart to take effect; 3 deferred fixes, one destroys a worktree.
- [answer short](reply-length-only-elaborate-if-asked.md) — Kevin's standing rule; elaborate only when asked. Global, also in CLAUDE.md.
- [stale worktree names](wip-stale-worktree-names-pr.md) — UNPUSHED branch, no PR exists. Blocked on 4 round-5 items plus 2 clean rounds.

## Moved here from the umbrella scope
- [hydra daemon bun shadowed by dot bun](hydra-daemon-bun-shadowed-by-dot-bun.md) — The hydra daemon can run a DIFFERENT bun than Kevin's shell — helpers.ts prepends ~/.bun/bin
- [hydra codex sessions gotchas](hydra-codex-sessions-gotchas.md) — Running codex-engine hydra sessions: attach lands on the empty hydra-anchor window (TUI is on window 1)
- [respawn must be in a thread](respawn-must-be-in-a-thread.md) — `respawn` only works inside a thread and only when the message is nothing but the command
- [fenced commands never route](fenced-commands-never-route.md) — Wrapping ANY hydra router command in a ``` code fence silently kills it
- [hydra spawn cwd and memory scope](hydra-spawn-cwd-and-memory-scope.md) — hydra has NO per-spawn cwd option: cwd is SPAWN_CWD or a worktree path. Consequence
- [daemon restart via bash not cli](daemon-restart-via-bash-not-cli.md) — Restart the hydra daemon via bash restart-daemon.sh (sources .env → CLAUDE_CONFIG_DIR=.claude-byte)

## Previously unindexed, moved from the umbrella
- [bridge flap duplicate byte](bridge-flap-duplicate-byte.md) — Daemon bridge disconnected/replacing/registered for session X flapping in a tight loop = a session spawned with a DUPLICATE bridge byte (2 tmux
- [there is NO worktree-target allowlist](build-wt-worktree-targets.md) — resolved 2026-07-07: any git repo under SPAWN_CWD works. The root cause was an inline # comment breaking SPAWN_CWD in the slack .env. Note `build-wt:` itself no longer exists; spawn_session's worktree param is the live path.
- [claude config topology](claude-config-topology.md) — Kevin's Claude Code config dirs; the .claude-byte half is RETIRED as of 2026-09-26
- [Claude-in-Chrome DOES work on the bridge](claude-in-chrome-unavailable-on-bridge.md) — the filename is dead wrong; it works since 2026-07-27. Probe with list_connected_browsers first.
- [disconnected live sessions bridge death](disconnected-live-sessions-bridge-death.md) — Health shows N live (0 connected, N disconnected) — session bridge MCP subprocesses died; a daemon restart does NOT fix it
- [hydra hardcoded claude config paths](hydra-hardcoded-claude-config-paths.md) — the .claude/.claude-byte split is GONE (2026-09-26); keep it for the failed-resume tombstone bug
- [hydra test pure module convention](hydra-test-pure-module-convention.md) — hydra testing — daemon/config.ts and dashboard.ts aren't test-importable; put pure logic in dependency-free modules
- [post-resign session recovery](post-resign-session-recovery.md) — HISTORICAL (2026-06-30 tmux kill-server wipe). Keep for the recovery cascade recipe; do not act on it as a live task.
- [Slack attachments break BOTH ways](slack-attachments-thread-reply-bug.md) — inbound images never reach the bridge, and OUTBOUND is broken the same way: reply's files: param reports sent and uploads, but nothing surfaces to Kevin. Confirmed 2026-09-08.
- [spawn default model](spawn-default-model.md) — How to set the default model for hydra spawned sessions — HYDRA_MODEL in the slack .env, forwarded by start-daemon.sh, needs a daemon restart
- [spawned session crash recovery](spawned-session-crash-recovery.md) — After a spawned-session process crash/restart (e.g. spend-limit 429): background shells lose cwd + sandbox path visibility
- [todo design autospawns session](todo-design-autospawns-session.md) — OPEN TODO — when `design` is invoked from the main thread, spawn a dedicated session for it instead of working inline in main.
- [todo fix unresponsive on bridge](todo-fix-unresponsive-on-bridge.md) — OPEN TODO — fix sessions going effectively unresponsive to Kevin on the bridge when awaiting input (he had to attach to tmux to reach me).

## Added
- [project hydra console billing](project_hydra_console_billing.md) — RETIRED 2026-09-26: .claude-byte is dead, fleet runs CLAUDE_CONFIG_DIR=~/.claude; billing under the byte login was wrong
- [Raindrop usage live](raindrop-usage-live.md) — shipped 2026-09-21; LAST(cumulative) vs SUM(delta), and why raw token sums mislead on cost
- [Raindrop query MCP access](raindrop-query-mcp-access.md) — mcp.raindrop.ai needs a Query SDK key (not the write key); creation may be org-owner gated
- [transcript phase classification](transcript-phase-classification.md) — measured: per-window tool-name phase rules collapse at 60s (98% "plan"); latch instead. Plus the ~3x dedup trap and the subagents/ layout.
- [wip usage phase attribution](wip-usage-phase-attribution.md) — MERGED 2026-09-29 as 0f8b447 (PR #409). Kept for the traps and the 8 review rounds; the live follow-ups are in [[handoff-usage-phase-followups]].
- [a wt/ spawn can claim your worktree](worktree-claimed-by-wt-spawn.md) — resets it to main under you; branch ref survives, recover into a NEW path, and re-check any reviewer pointed at the old one.
- [usage-phase follow-ups handoff](handoff-usage-phase-followups.md) — PR #409 merged + deployed; the 3 held items (mutation leftovers, two promises to sf8193, PR 2) with the traps already disproved.
- [hermetic git test fixtures PR](hermetic-git-test-fixtures-pr.md) — PR #418 2026-09-29; Bun env-snapshot trap, a toEqual on a constant is not a pin, `gt submit` fails on this repo, 5 follow-ups
- [re-bank with unchanged totals loses a tick](raindrop-rebank-unchanged-totals-trap.md) — restarted must move the totals, or raindrop drops the next window.
- [gate checklist](gate-checklist.md) — CI-parity checks to run once before review round 1 (read by CLAUDE.md gate step 0).
- [batched orphan alerts](batch-orphan-alerts-pr.md) — `recover all` skips orphans; no disconnect timestamp exists; CI env trap
- [bridge exit records](bridge-exit-records-pr.md) — grep 'bridge exit check' after a bridge death; 16 local-only test failures on main
