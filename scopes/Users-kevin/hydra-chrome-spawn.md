---
name: hydra-chrome-spawn
description: How Claude-in-Chrome relates to hydra-spawned sessions — no per-session flag; the --no-chrome trap
metadata: 
  node_type: memory
  type: reference
  originSessionId: 74df7565-7856-4e0c-96cf-2772ee7c849d
  modified: 2026-08-05T21:24:47.659Z
---

Claude-in-Chrome for hydra sessions: there is NO per-session "chrome flag" in the running hydra (main/HEAD). Spawn flags are hardcoded — `daemon/session-lifecycle.ts:437` pins `--channels plugin:discord@claude-plugins-official`; the claude launch (line ~625) passes no chrome flag. Chrome is a `claude` CLI capability (`--chrome`/`--no-chrome`), not an MCP channel hydra injects. The main session (slack-byte) does NOT have `mcp__Claude_in_Chrome__*` tools.

TRAP (commit 47118d4 "pass --no-chrome to byte and spawned sessions", on UNMERGED branch `fork/fix/bridge-autoconnect-gate`): a spawned session WITHOUT `--no-chrome` boots into an interactive "use my browser?" prompt that blocks on stdin forever in a detached tmux spawn → no bridge registration, silent dead bot. That's why `--no-chrome` was made the safe default. So naively enabling chrome on a spawned session can hang it.

To actually give a spawned session a browser: wire a per-session `--chrome` opt-in into the spawn path that also pre-answers/avoids the interactive prompt — a hydra code change, not a flag flip. `cachedChromeExtensionInstalled=true` in `~/.claude/.claude.json` (extension installed); enabling is the Claude Code `/chrome` command for INTERACTIVE sessions. Kevin asked to "restart prism with the chrome flag" 2026-08-05; nova FE builds needing screenshots ([[nova-build-worktree-screenshots]]) hit this. See [[bridge-state-recovery]] for daemon restart mechanics.
