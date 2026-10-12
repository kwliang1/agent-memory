---
name: daemon-restart-via-bash-not-cli
description: "Restart the hydra daemon via bash restart-daemon.sh (sources .env → CLAUDE_CONFIG_DIR=.claude-byte), NOT `hydra restart` (TS CLI) which inherits the ambient config-dir and drifts spawns off the bot config — breaking the Linear MCP."
metadata: 
  node_type: memory
  type: feedback
  originSessionId: 0e543ade-488f-42be-95ee-8849ec3b5a75
  modified: 2026-07-22T23:12:20.624Z
---

**Always restart the hydra daemon via bash `hydra/restart-daemon.sh`** (with `SPAWN_CWD=/Users/kevin/RubymineProjects`), NOT the TS CLI `hydra restart slack`.

**Exact command that works (verified 2026-07-22):** from the hydra checkout, `CHAT_PLATFORM=slack HYDRA_STATE_DIR=/Users/kevin/.claude/channels/slack ./restart-daemon.sh`. `CHAT_PLATFORM` is now **required** — `env-setup.sh` hard-errors (not warns) when it's unset and >1 platform state dir exists under `~/.claude/channels`. The script compile-checks BEFORE killing (bad build → old daemon stays up), then relaunches into tmux session `slack-daemon`; the state-dir `.env` supplies `CLAUDE_CONFIG_DIR`/`HYDRA_MODEL`/tokens. Socket back in ~1s. The daemon runs `bun run daemon.ts` **from source**, so it picks up whatever branch the working tree is on — restarting is how you deploy a branch locally. Safe for a spawned session to run against itself (bridges reconnect ~5s; only Slack I/O via reply/react blips, local Bash is unaffected). `restart-daemon.sh` prints a "DEPRECATED: use hydra restart" banner — ignore it, the CLI path is the one that breaks config-dir (below).

**Why (verified 2026-07-21):** `restart-daemon.sh` sources `env-setup.sh` → the state-dir `.env`, so the daemon gets `CLAUDE_CONFIG_DIR=/Users/kevin/.claude-byte` + `HYDRA_MODEL` correctly. The TS CLI (`hydra restart`, cli/lifecycle.ts) instead **inherits the invoking shell's ambient `CLAUDE_CONFIG_DIR`** — when run from Kevin's personal Claude Code that's `/Users/kevin/.claude`. A Jul 19 `hydra restart` drifted the daemon to `.claude` for 2 days, so all spawned sessions ran under Kevin's **personal** config instead of the bot.

**Consequence — MCP connections are scoped per `CLAUDE_CONFIG_DIR`** (see [[claude-config-topology]]): server registrations live in each config's `.claude.json` `mcpServers`, and remote-MCP OAuth tokens live in that config dir's credential store. **Linear (`mcp.linear.app`) is registered + authed ONLY in `.claude-byte`** (`~/.claude-byte/.claude.json:1005`), not `.claude`. So the drift broke Linear for spawned sessions (the "callback not reaching hydra" symptom — the session was under a config with no Linear). Fixing config-dir (bash restart → `.claude-byte`) restored Linear; verified via `list_teams`.

**Restart caveats:** cycles the router only — running session tmux panes/Claude processes SURVIVE (independent tmux; they re-register). BUT a restart does NOT retroactively re-config already-running sessions; they keep whatever config-dir they launched under. Only NEW spawns pick up the corrected config — so a session that needs Linear after a config fix must be **respawned**. Verify after restart: `ps eww <daemon-pid>` shows `CLAUDE_CONFIG_DIR=/Users/kevin/.claude-byte`, `HYDRA_MODEL`, clean `SPAWN_CWD`.
**RETIRED 2026-09-26 — ignore every `.claude-byte` instruction above.** The fleet runs `CLAUDE_CONFIG_DIR=/Users/kevin/.claude`; the slack `.env` says so and the repo has zero `claude-byte` references. After a correct `restart-daemon.sh`, `ps eww <pid>` showing `.claude` is right — do NOT re-restart to force `.claude-byte`. The Linear-only-in-`.claude-byte` consequence is historical too; re-verify MCP auth against `.claude` if Linear misbehaves. Kevin settled this: "billing is incorrect, we should never be using claude-byte anymore." See [[hydra-console-billing]].

**Still current:** use bash `restart-daemon.sh`, not the TS CLI. Verified working 2026-09-26 from `/Users/kevin/RubymineProjects/hydra`:
`CHAT_PLATFORM=slack HYDRA_STATE_DIR=/Users/kevin/.claude/channels/slack SPAWN_CWD=/Users/kevin/RubymineProjects ./restart-daemon.sh`
It compile-checks before killing (bad build leaves the old daemon up), socket returns in ~1s, and all 32 tmux sessions survived unchanged. The daemon runs from source, so restarting deploys whatever the checkout is on.

---

**2026-09-29 — the bash script now FAILS AFTER killing the daemon, and the CLI is clean. Prefer the CLI.**

Ran bare `bash restart-daemon.sh` (my error — the recipe above requires `CHAT_PLATFORM` and `HYDRA_STATE_DIR`) and got:

```
Pre-flight compile check...
Killing daemon...
Starting daemon...
restart-daemon.sh: line 50: HYDRA_STATE_DIR: unbound variable
```

**The compile-check-before-kill protection does not cover a missing env var.** The var is dereferenced at line 50, in the *relaunch* block, which runs AFTER the kill. So a bare invocation is a real outage, not a safe abort — the daemon was down until I started it again. Pass the vars or don't use the script.

**`bun cli/hydra.ts restart slack` recovered it cleanly and is now the better path.** It compile-checks, runs *module validation* (the script does not), waits for the socket, and — the thing this file warned about — **did NOT drift the config dir**. Verified with `ps eww` on the new pid:

```
CHAT_PLATFORM=slack   CLAUDE_CONFIG_DIR=/Users/kevin/.claude
HYDRA_STATE_DIR=/Users/kevin/.claude/channels/slack
SPAWN_CWD=/Users/kevin/RubymineProjects   HYDRA_MODEL=claude-opus-5[1m]
```

All correct, so the July ambient-inheritance bug this file is built around appears fixed. The `DEPRECATED: use 'hydra restart <platform>'` banner the script prints is right; the advice above to ignore it is stale.

**Fleet survived intact:** 32 tmux sessions before and after, 29 registry entries, zero missing. Snapshot `tmux ls | cut -d: -f1 | sort` before and `comm -23` after — that is what proves it rather than a count matching by luck.
