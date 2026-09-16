---
name: hydra-slack-setup
description: "Kevin's working local Hydra Slack bot — config, auth, and the gotchas that broke it"
metadata: 
  node_type: memory
  type: project
  originSessionId: cbe56577-d3b9-4e3a-b91b-6f8b9adc56f5
---

Kevin runs Hydra as a **Slack** bot (bot user `senna`, AngelList workspace, app possibly renamed "Russell") to drive Claude sessions on his repos under `/Users/kevin/RubymineProjects`. VERIFIED WORKING 2026-06-25 (inbound DMs + replies round-trip).

**Auth = pinned OAuth token, NOT keychain.** Token at `~/.hydra-claude-token` (chmod 600), from `claude setup-token`. Reason: the keychain login only works with `CLAUDE_CONFIG_DIR` UNSET; setting it (which the daemon does for every spawn, `session-lifecycle.ts:353`) returns "Not logged in". Token authenticates regardless of config dir. `apiKeyHelper` does NOT work (it's for `sk-ant-api` keys; rejects the `sk-ant-oat` OAuth token).

**Dedicated config dir `~/.claude-byte`** (NOT `~/.claude`): clone of `~/.claude.json` with `projects` dropped + native `slack` MCP connector removed (avoids reply-as-Kevin hijack). `~/.claude-byte/settings.json` MUST have: `theme:dark`, `skipDangerousModePermissionPrompt:true`, `skipAutoPermissionPrompt:true`, and **`enabledPlugins:{"discord@claude-plugins-official":true}`** — without enabledPlugins the bridge MCP server never starts (channels banner shows but no `server.ts` process). Bridge plugin copied into `~/.claude-byte/plugins` (discord only).

**Daemon `.env`** (`~/.claude/channels/slack/.env`): `CHAT_PLATFORM=slack`, `SLACK_BOT_TOKEN`/`SLACK_APP_TOKEN`, `SPAWN_CWD=/Users/kevin/RubymineProjects`, `CLAUDE_CONFIG_DIR=/Users/kevin/.claude-byte`, `HYDRA_CLAUDE_TOKEN_FILE=/Users/kevin/.hydra-claude-token`.

**Local code edits (uncommitted) to make spawns auth:** `session-lifecycle.ts` injects `export CLAUDE_CODE_OAUTH_TOKEN="$(cat $HYDRA_CLAUDE_TOKEN_FILE)"` into the spawn inner command; `start-daemon.sh` forwards `HYDRA_CLAUDE_TOKEN_FILE`. Added `bun 1.3.13` to `~/.tool-versions` (global) so bun resolves in the deep plugin cwd. Repo `.tool-versions` also added (bun 1.3.13).

**Launch (run from a NORMAL terminal, not inside a Claude session):**
- Daemon: `CHAT_PLATFORM=slack HYDRA_STATE_DIR=~/.claude/channels/slack ./start-daemon.sh`
- Bot: tmux session running `... CLAUDE_CONFIG_DIR=~/.claude-byte CLAUDE_CODE_OAUTH_TOKEN=$(cat ~/.hydra-claude-token) caffeinate -i claude --channels plugin:discord@claude-plugins-official --dangerously-skip-permissions '<prompt>'`. The repo's `start-slack-byte.sh` does NOT work as-is (hardcodes `~/.angellist-claude-token` + `~/.claude-slack`).

**Gotchas that cost hours:**
- The bridge plugin is named `discord@claude-plugins-official` but is **platform-agnostic** — no Discord involved. The bot sometimes self-describes as Discord and suggests `/discord:configure` (wrong on Slack).
- **NO pipe on the `claude` launch command** (`| tee` etc.) — a pipe makes stdout non-TTY so claude runs the prompt once and exits.
- Only ONE bridge process may run; orphaned `bun server.ts` bridges from old launches register as "main" and split/steal routing. Running the bridge by hand also bumps the bot's registration.
- Slack app (built blank, not from manifest) needed manual: **Event Subscriptions** bot events (`message.im`, `app_mention`, `message.channels`, `message.groups`), **App Home → Messages Tab → allow sending**, and bot scope **`chat:write`** (was the final missing piece — 👀 react worked via `reactions:write` but replies failed `missing_scope`).
- Channels gate (managed-settings `channelsEnabled:true`, sudo) is mandatory on AngelList Enterprise.
- tmux server freezes the launching env into its global env; starting the daemon from inside a Claude session leaked `CLAUDE_CONFIG_DIR`/`CLAUDECODE` into spawned sessions.

**Persona:** Russell from *Up* (warm, playful, chipper 10-yr-old Wilderness Explorer; whimsical but thorough). Lives in `~/.claude-byte/russell-persona.md`, pulled via `@russell-persona.md` import from `~/.claude-byte/CLAUDE.md`. The bot greets as "Russell reporting for duty". NOTE: launch prompt must be **apostrophe-free** (a `'` breaks the tmux/shell quoting and the bot dies on launch).

**Sub-agent personas (for workflows):** flat persona files in `~/.claude-byte/` (`mr-fredricksen-persona.md`, `kevin-persona.md`, `doug-persona.md`) AND proper subagent definitions in `~/.claude-byte/agents/{russell,mr-fredricksen,kevin,doug}.md` so workflows auto-pull via `agent(prompt,{agentType:"doug"})`. Mapping: Mr. Fredricksen=gruff critic, Kevin(bird)=discovery/search, Doug=synthesizer/executor, Russell=orchestrator. All share staff-engineer rigor; only voice differs. Workflow scripts are sandboxed (no file reads) — so for the flat files the orchestrator must Read + paste into agent prompts; the `agents/` defs are the automatic path.

**Durability (DONE):** `start-slack-byte.sh` fixed for this setup (CONFIG_DIR→`~/.claude-byte`, token→`~/.hydra-claude-token` via `HYDRA_CLAUDE_TOKEN_FILE`, model→opus-4-8). launchd agent `~/Library/LaunchAgents/com.hydra.watchdog.plist` (label `com.hydra.watchdog`) runs `watchdog.sh` every 120s — revives daemon and/or bot if down, no-op when healthy. Bot-revival tested working. Unload with `launchctl unload`.

**Spawn naming fix:** `session-lifecycle.ts` previously set `You are ${tmuxName}` so spawns called themselves by the cute label (e.g. "Spark"). Fixed all 3 prompt variants to keep the CLAUDE.md persona (Russell) and treat the label as tmux-only; persona file also anchors "your name is always Russell". **Takes effect on next daemon restart** (staged; not restarted yet to avoid disrupting an active spawned session).

Spawn end-to-end VERIFIED: `spawn-wt: treasury ...` spawned a worktree session that rebased + pushed real work.

See [[hydra-overview]] for what Hydra is.
