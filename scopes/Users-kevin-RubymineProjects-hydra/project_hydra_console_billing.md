---
name: hydra-console-billing
description: Hydra fleet billing moved to console/API via .claude-byte login (Aug 27 2026); helpers.ts configDir bug requires pinned env on hydra up/restart
metadata: 
  node_type: memory
  type: project
  originSessionId: a217a88d-d68e-4308-9a42-0cfce7dfce54
  modified: 2026-08-28T06:31:28.507Z
---

Hydra (~/RubymineProjects/hydra, slack platform) auth: all sessions share `CLAUDE_CONFIG_DIR=/Users/kevin/.claude-byte`; on 2026-08-27 Kevin switched that dir's login to Anthropic Console (`billingType: usage_based`) — keychain entry `Claude Code-credentials-a21d4e95`. Personal `~/.claude` stays on the AngelList work login (blocked that day by an org **individual spend limit**, not the 5h window).

**Why:** `cli/helpers.ts` `resolveConfig` captures `configDir` BEFORE sourcing the state-dir `.env` (unlike `spawnCwd`, re-read after), so `hydra up/restart` from a clean shell silently gives daemon+byte `~/.claude`.

**How to apply:** prefix hydra lifecycle commands with `CLAUDE_CONFIG_DIR=/Users/kevin/.claude-byte` until the one-line fix lands. Migrate a session between config dirs: copy its `projects/<cwd-slug>/<claudeSessionId>.jsonl` to the target dir, `hydra kill <name>`, then type `resume` in its Slack thread (tier-1 `--resume` keeps context). Running Claude sessions never re-read the keychain while healthy — restart is the only billing flip. Known quirk: after kill+resume in the same DM channel, another killed session's queued bootstrap prompt can be re-delivered into the resumed session (harmless context noise). Settings hot-reload covers `apiKeyHelper` (docs-verified) if a per-dir helper is ever preferred over /login.
