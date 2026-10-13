---
name: claude-config-topology
description: "Where Kevin's Claude Code configs live — main interactive vs the byte/slack bridge"
metadata: 
  node_type: memory
  type: reference
  originSessionId: 77f6b237-62fa-41a6-80e3-a258759c9022
  modified: 2026-09-11T18:06:12.074Z
---

Kevin runs multiple Claude Code configs:
- **Main interactive Claude Code** → user config is `~/.claude.json` (home root, `CLAUDE_CONFIG_DIR` UNSET). Holds all his claude.ai/AngelList remote MCP servers (Linear, Datadog, Snowflake, etc.). This is "his" Claude Code — the default target when he says "add X for me."
- **Byte / Slack bridge (this Russell session)** → `CLAUDE_CONFIG_DIR=~/.claude-byte`, config `~/.claude-byte/.claude.json`. Auth pinned to the AngelList work account via `CLAUDE_CODE_OAUTH_TOKEN`.
- `~/.claude/` is not the main *interactive* config dir, but **correction 2026-09-11: `~/.claude/.claude.json` DOES exist** (71897 B). All three trees have one: `~/.claude.json` (115 KB), `~/.claude-byte/.claude.json` (91 KB), `~/.claude/.claude.json` (72 KB). The earlier "only backups" claim was wrong.
- **`~/.claude/` still reaches every session anyway**, as an *ancestor* `.claude/` dir for any cwd under `/Users/kevin/` — its `CLAUDE.md` body, `agents/`, and `skills/` all load regardless of `CLAUDE_CONFIG_DIR`. See [[claude-md-ancestor-loading-rules]] for the verified matrix and why that blocks a naive tree merge.

**How to apply:** To act on his MAIN config from this slack session, run the `claude` CLI with `env -u CLAUDE_CONFIG_DIR` (this session exports `CLAUDE_CONFIG_DIR=~/.claude-byte`, which would otherwise hit the wrong config). Use `-s user` scope for things that should be available across all his projects. Example that worked (2026-06-26): added the official 1Password MCP server (`/Applications/1Password.app/Contents/MacOS/onepassword-mcp`, stdio, connects via the app's "Integrate with MCP clients" toggle) with `env -u CLAUDE_CONFIG_DIR claude mcp add 1password -s user -- <binary>`. See [[main-session-spawn-notifications]] for the bridge architecture.


**RETIRED 2026-09-26 — `.claude-byte` is dead.** The whole fleet now runs `CLAUDE_CONFIG_DIR=/Users/kevin/.claude` (Kevin: "billing is incorrect, we should never be using claude-byte anymore"). Every `.claude-byte` claim above is historical. Verified same day: zero `claude-byte` references remain in the repo, `claudeConfigDir()` defaults to `.claude` (the old `.claude-personal` default is gone), and the slack `.env` pins `.claude`. See [[hydra-console-billing]].
