---
name: hydra-session-resurrection
description: "How to resurrect Hydra spawned sessions after tmux kill-server (or daemon crash), plus the gotchas that bite"
metadata: 
  node_type: memory
  type: project
  originSessionId: 05272b10-e648-41e0-86db-c89848482510
---

Hydra's `sessions.json` persistence is **re-attach only**, not cold resurrection. On every daemon boot, `SessionRegistry.loadPersisted()` (`daemon/sessions.ts:222`) reads `sessions.json` and for each entry runs `tmux has-session`; dead ones are pruned and the file is rewritten. So a **daemon-only** crash is survivable (spawned tmux sessions keep running, daemon re-binds), but **`tmux kill-server` is not** — it kills the spawned sessions too, so on the next daemon boot every liveness check fails and `sessions.json` is pruned to `[]`. Verified 2026-06-29: kill-server → watchdog restarted daemon+bot → all 7 spawns pruned.

**Manual resurrection (done 2026-06-29, worked):** the out-of-band snapshot `~/.claude/channels/slack/sessions-pre-resign-backup.json` holds the pre-kill session list (sessionId, claudeSessionId, threadId, worktreeRepo/Path). For each session: launch a tmux session named after `tmuxName` running `claude --resume <claudeSessionId>` in its `worktreePath` cwd, with `HYDRA_SESSION_ID=<hydra sessionId>` + `DAEMON_SOCK` + `CLAUDE_CONFIG_DIR=~/.claude-byte` + `CLAUDE_CODE_OAUTH_TOKEN` exported (mirror `doSpawnSession`'s inner cmd, `session-lifecycle.ts:353`). Then: kill the empty-registry daemon, write the entries into `sessions.json`, restart the daemon → `loadPersisted` sees the tmux sessions alive → restores routing (`restored N session(s), pruned 0`). Order matters: tmux must be alive **before** the daemon boots, and kill the daemon before writing the file so it can't clobber. Transcripts live at `~/.claude-byte/projects/-Users-kevin-...-<worktree>/<claudeSessionId>.jsonl` — needed for `--resume`.

**Gotchas:**
- **Crash-loop destroys worktrees.** A resumed session that crashes triggers the daemon's death detection → auto-respawn, and `killSession` (`session-lifecycle.ts:64`) **removes the worktree + deletes branch `wt/<name>`**. Cascades to a new catalog name (e.g. pixel→drift). So a crashed resume loses its git worktree/branch — recreate with `git worktree add -b wt/<name>` before re-resuming. The conversation transcript survives regardless. (pixel crash-looped pixel→pixel→drift on 2026-06-29; 6/7 others stayed up fine.)
- **Main bot parks after a daemon restart.** Observed: slack-byte idle at 0% CPU with an incoming channel message sitting unprocessed in its `❯` input. The bridge delivers messages as `mcp.notification('notifications/claude/channel')` (`bridge.ts:161`); when fully idle it doesn't reliably start a new turn. `tmux send-keys ... Enter` did NOT unstick it. Fix: restart slack-byte (`./start-slack-byte.sh`) — fresh context, responsive again; its transcript persists for later resume.
- **👀 means delivered, not answered.** The 👀 ackReaction is applied inside `deliverToSession`/the main path right before the message is queued to the session (`router.ts:78`, `:429`). So "👀 but no reply" = daemon delivered it; the silence is downstream (session parked, or just slow — a long think shows only 👀 until the reply lands). Outbound sends are Web API and were error-free even while the Socket Mode gateway flapped (`connection stale (239s)… reconnect` every ~4min — self-heals, separate from replies).
- Run all launches from a normal context with CLAUDE_* vars stripped (`env -u CLAUDECODE -u CLAUDE_CONFIG_DIR ...`); the tmux server (already up from the watchdog) keeps a clean global env.

See [[hydra-slack-setup]] for the base config/auth.
