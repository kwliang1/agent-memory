---
name: bridge-state-recovery
description: "Where the Discord/Slack bridge persists state so reboots aren't lossy; what survives vs dies on reboot"
metadata: 
  node_type: memory
  type: reference
  originSessionId: 74df7565-7856-4e0c-96cf-2772ee7c849d
  modified: 2026-08-21T23:45:55.547Z
---

Kevin runs a Discord/Slack bridge (DM chat_id `D0BE3RB4Y00`, same id on both). On computer reboot, live tmux worker sessions die (`list_sessions` → `[]`, cannot be resurrected as processes) but these files persist under `~/.claude/channels/slack/`:

- `threads.json` — every thread/session record: `topic`, `threadUrl` (Slack permalink = the "message link"), `description` (the short status shown on the "home dashboard"), `sessionHistory[].endedAt` (null-ish = never formally closed). ~107 records; most `description` are empty (`—`).
- `sessions.json` — worker session records (tmux name, capabilities, threadUrl, spawnLogPath).
- `pr-watches.json` — active PR watches; these SURVIVE reboot and keep working.
- `transcripts/` (build/review .md), `inbox/` (pasted images/audio), `spawn-logs/`.

Recovery = rebuild the "home dashboard" (per-thread description + message link) from `threads.json` + `pr-watches.json`, since the live session list is empty after reboot. Kevin has hit this "recover all after reboot" flow more than once.

CRITICAL respawn detail: to resume a dead worker ON ITS ORIGINAL THREAD, call `spawn_session` with `chat_id` + `message_id` set to that thread's anchor message id (the `p<digits>` in `threadUrl`, dotted: `p1785452353841569` → `message_id: "1785452353.841569"`). OMITTING `message_id` creates a brand-new thread — Kevin does NOT want that; it clutters the home view. After spawn, call `set_description(session_id, ...)` to populate the dashboard line. Kevin reads the home "Active Sessions" list; keep descriptions terse: `TICKET: what — repo #PR (state)`.

DAEMON ARCHITECTURE (hydra, `~/RubymineProjects/hydra`): the bridge is a proxy (`server.ts`) → daemon over a unix socket (`~/.claude/channels/slack/daemon.sock`). Daemon runs `bun run daemon.ts` from SOURCE, so a code change needs a daemon restart to take effect. Restart safely with `hydra restart slack` (validates/compile-checks modules BEFORE killing, then restores sessions). CAUTION: the daemon serving the live slack bridge may be a MANUALLY-started instance (`CLAUDE_CONFIG_DIR=/Users/kevin/.claude`, piped to `~/hydra-slack-daemon.log`), distinct from the `com.hydra.watchdog` launchd job (configured for `.claude-byte`) — don't assume the watchdog respawns the manual instance. Restarting drops the bridge that `reply` runs through, so prefer having Kevin run `hydra restart slack` himself.

STALE-CHECKOUT TRAP (2026-08-21): the daemon runs from the ~/RubymineProjects/hydra working tree, and that checkout can be on CURRENT main but far BEHIND origin — found it on an Aug-9 commit, **60 commits behind origin/main**, so merged fixes (e.g. the pane-probe flap fix #310) had never deployed even though "merged." Worse, a restart from the stale checkout re-runs the old code. So when a merged hydra fix "isn't taking effect": (1) `git -C ~/RubymineProjects/hydra fetch && git rev-list --count HEAD..origin/main` — if behind, `git pull --ff-only origin main` (safe when ahead=0 + clean tree); (2) THEN `hydra restart slack` so it loads current source (files pulled while it runs are inert until restart — bun has no hot-reload). Verify the running daemon's expected fix is actually in the checkout HEAD (`git merge-base --is-ancestor <sha> HEAD`), not just merged on origin.

DASHBOARD LINK BEHAVIOR: session links should point to each session's LATEST reply (`getMessageUrl(threadId, lastReplyId)`), falling back to the thread anchor. Fixed in PR #185 (sf8193/hydra, branch `kevinliang/dashboard-link-last-reply`): reply handler now calls debounced `refreshDashboard()` on every `lastReplyId` change, and `list_sessions` builds its url from `lastReplyId` (was hardcoded to `s.threadUrl`). Until that PR merges + daemon restarts, the bug recurs on a fresh daemon start. Manual workaround to refresh a stale dashboard: any `set_description` call triggers `refreshDashboard()`.

DEDUP ON RECOVERY: when respawning workers, dedup by the actual PR/ticket they own, not just by thread — a naive per-thread respawn can put two sessions on the SAME PR. 2026-08-05: respawned flint on #8067 (BANK-1486) while qubit was also driving #8067 → flint had stale "merge-ready" info and nearly merged ahead of qubit's live review fixes. Also: re-anchoring a session onto an orphaned/un-threadable message (e.g. the bare "generalize it" message) produces a broken dashboard deep-link that NO reply can fix — the thread itself can't host replies. Respawn onto a clean thread instead, or kill if the work is a duplicate.

2026-08-05 reboot: respawned 8 workers anchored to originals — flint(BANK-1486/#8067), ember(BANK-1506/#8375+v31974), orbit(BANK-1634/#8426), prism(BANK-1667/nova#9007), bloom(MMF-IVC/v31124+#8120), qubit(BANK-1746/blocked on CA 356027), drift(CSV-entity-ingest), atlas(BANK-1586). Plus auto-spawned nova(entity transfer). tmux names get reassigned on respawn — the thread + topic are the source of truth, not the name.
