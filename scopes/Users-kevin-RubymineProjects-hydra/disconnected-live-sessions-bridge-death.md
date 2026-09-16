---
name: disconnected-live-sessions-bridge-death
description: Health shows "N live (0 connected, N disconnected)" — session bridge MCP subprocesses died; a daemon restart does NOT fix it. Recover via kill→recover per session.
metadata:
  node_type: memory
  type: reference
  originSessionId: 0e543ade-488f-42be-95ee-8849ec3b5a75
  modified: 2026-07-29T19:35:24.461Z
---

**Failure mode (seen 2026-07-29):** daemon health shows `19 live (0 connected, 19 disconnected)` + queued messages piling up, while the daemon and every session `claude` process are alive and healthy.

**Root cause:** the "bridge" is a **per-session MCP subprocess** (`bun server.ts`, the discord plugin) that each `claude` launches as a child and which dials the daemon unix socket. `bridge.ts:86` has a 5s auto-reconnect loop — but the subprocesses had **died** (only ~3 of 19 `claude` procs still had a live bridge child), and a dead process can't run its reconnect loop. Idle sessions never re-invoke the *discord* plugin (their work uses Bash/Read/etc.), so `claude` never notices the dead MCP server and never respawns it → permanent silent disconnect. Diagnose by counting bridge children: `for cp in $(pgrep -f "claude --model"); do pgrep -P $cp >/dev/null && echo live; done`.

**A daemon restart does NOT fix this** — I tried; still 0/19. The missing piece is claude-side (the MCP subprocess), not daemon-side. `restart-daemon.sh` recreates the socket but there's no bridge process left to dial it. Only the MAIN session recovered, because Kevin ran `/mcp` which respawned main's bridge subprocess.

**NUANCE (confirmed 2026-07-30, a DIFFERENT restart): a restart DOES reconnect sessions whose bridge subprocess is still ALIVE.** After a dashboard-fix restart, **15 bridges re-registered** ("daemon: bridge registered for session <id>") — the active/recent sessions (spark, moss, jade, comet, lark…) came back connected on their own. Only the LONG-STALE idle-for-days sessions (nova 4d, fern 21d, atlas 8d…) stayed `[disconnected]` — those had already lost their bridge subprocess before the restart. So the rule is: **restart re-registers any session whose `bun server.ts` bridge child is still alive; it cannot help one whose bridge child already died (that needs `/mcp` or respawn).** Verify post-restart via `grep "bridge registered" ~/hydra-slack-daemon.log | tail` (count unique session ids) rather than trusting the first `[disconnected]`-heavy vitals snapshot, which lags the reconnects.

**The relevant commands and what they actually do** (`daemon/router.ts`, `daemon/commands/global.ts`):
- `/reconnect` → `gateway.forceReconnect()` — **gateway (daemon↔Slack) only**, not session bridges. Useless for this.
- `recover [name|all]` → respawns **DEAD** sessions (`findDeadSessions()` — the "Dead (recoverable)" list), NOT disconnected-live ones. Preserves context: methods `resumed` (full) / `forked` (transcript) / `resurrected` (thread re-read).
- The Slack **gateway flaps every ~4 min** (`connection stale (239s) → reconnect`) but self-heals — that's an aggressive socket-mode keepalive, a RED HERRING, not the disconnect cause.

**Recovery for a disconnected-live session:** there is no direct daemon lever. Clean path = **`kill <name>` → session becomes "dead" → `recover <name>`** → respawns with full context + a fresh working bridge. Triage: `kill` stale idle-for-days sessions outright (dead weight); `kill`→`recover` only the active handful worth saving; `recover all` also cleans up already-dead sessions. Avoid the fragile `tmux send-keys /mcp` approach (drives an interactive menu).

**`recover` BUG for worktree sessions (seen 2026-07-29, glyph):** `recover <name>` kept crashing in ~1s with `No conversation found with session ID: <claude-id>` → exit 1. Root cause: a worktree build session ran with cwd = its treasury worktree (e.g. `/Users/kevin/RubymineProjects/.worktrees/treasury-glyph`), so its claude transcript is stored under the project hash `…--worktrees-treasury-glyph/<claude-id>.jsonl`. But hydra's recover respawns claude from the **generic cwd `/Users/kevin/RubymineProjects`**, and `claude --resume` scopes lookup by cwd-derived project hash → looks in the wrong project dir → "No conversation found" → instant crash. The transcript is NOT lost (glyph's was 2161 lines / 5.4MB, intact) — it's a cwd mismatch. Compounding it: treasury auto-cleans the worktree on session teardown (`make clean-worktree`), so even a cwd-correct resume has no working tree left, and uncommitted work is gone (committed work lives on the PR branch). **Fix for a crashed worktree session: don't retry `recover` — respawn FRESH** (new worktree, re-checkout the branch, continue from the PR). Mine the transcript only for forensic reasoning; the code state is gone. (Potential real hydra fix: recover should restore the original worktree cwd, not the generic SPAWN_CWD.)

**BEST FIX, confirmed 2026-07-29 on a SPAWNED session (`jade`), not just main:** Kevin running **`/mcp`** in that session's terminal respawns its bridge subprocess and the `reply` tool comes straight back — **context fully preserved, no kill→recover, no worktree loss.** Escalation order: `/mcp` first, kill→recover only if that fails. Ask him to run it; don't try to drive it yourself.

## The asymmetry: inbound keeps working
Only **session→daemon** dies. Kevin's messages still route correctly — the giveaway is they arrive as ordinary user input instead of `<channel source="..." chat_id="...">` tags. Confirm ingress by grepping the live log for `daemon: thread routing:` and finding `mappedSession=<your session_id>`. So "I don't see my messages landing" actually means "your replies aren't coming back" — say that, don't hunt a routing bug.

## Two-log split that hides everything (cost me a whole diagnosis pass)
`~/hydra-daemon.log` is fed by the long-lived **tmux wrapper**. `restart-daemon.sh` spawns a **new** bun process that does NOT inherit that `tee`, so the wrapper log **freezes** on its last wrapper-fed day (Jul 1 in my case) while live output goes to **`~/hydra-slack-daemon.log`** (24MB+). The wrapper pid and `cat ~/.claude/channels/slack/daemon.pid` are **different processes** — trust `daemon.pid` plus `daemon.alive` (fresh epoch-ms heartbeat). The obvious log path shows month-old data and looks like the daemon died.

**Never** route around a muted bridge via the AngelList Slack MCP (`slack_send_message`) — it authenticates as Kevin and would post as him into his own DM with the bot. Impersonating the user to work around dead infra is not an acceptable substitute for being mute.

Related: [[bridge-flap-duplicate-byte]] (a different flap: duplicate bridge byte), [[daemon-restart-via-bash-not-cli]], [[shared-checkout-worktree-isolation]], [[always-reply-via-tool]].
