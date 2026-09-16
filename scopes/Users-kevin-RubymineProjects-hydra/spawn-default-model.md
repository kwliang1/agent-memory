---
name: spawn-default-model
description: "How to set the default model for hydra spawned sessions — HYDRA_MODEL in the slack .env, forwarded by start-daemon.sh, needs a daemon restart. Fable available as of 2026-07-08."
metadata: 
  node_type: memory
  type: reference
  originSessionId: 0e543ade-488f-42be-95ee-8849ec3b5a75
---

Spawned sessions' default model = `spawnModel()` in hydra `shared/constants.ts` = `process.env.HYDRA_MODEL || DEFAULT_MODEL` (DEFAULT_MODEL = `claude-opus-4-6[1m]`). `spawn_session` MCP tool has **no model param**, so the only lever for the default is `HYDRA_MODEL`. (Per-directive override exists via the daemon's `build-wt:`/spawn parsing, e.g. `build-wt: treasury 3 fable …` → router.ts parses the `fable` alias → `claude-fable-5[1m]`.)

Current default (2026-07-09): **`claude-opus-4-8[1m]`** (Kevin switched back from Fable). History: 2026-07-08 → fable-5.

To set the default:
1. Set `HYDRA_MODEL=claude-fable-5[1m]` in `/Users/kevin/.claude/channels/slack/.env` (comment on its OWN line — see [[build-wt-worktree-targets]]).
2. **hydra bug fixed:** `start-daemon.sh`'s `ENVS` allowlist did NOT forward `HYDRA_MODEL` (only PATH/STATE_DIR/SPAWN_CWD/CHAT_PLATFORM/CLAUDE_CONFIG_DIR), so the `.env` value was inert. Added `[ -n "${HYDRA_MODEL:-}" ] && ENVS="$ENVS HYDRA_MODEL='$HYDRA_MODEL'"`. This is an UNCOMMITTED edit on the main hydra checkout — should be committed/PR'd. `DEFAULT_MODEL` in constants.ts still hardcoded to opus-4-6.
3. Restart the daemon (`hydra/restart-daemon.sh`) — verify with `ps eww <daemon-pid>` that `HYDRA_MODEL` is present.

**Per-spawn model (a specific session on a non-default model, e.g. Kevin says `build-wt: treasury 2 opus-5`):** my two spawn paths SPLIT worktree vs model — MCP `spawn_session` does worktree but has NO model param (→ defaults to HYDRA_MODEL); the hydra CLI `bun cli/hydra.ts spawn "<prompt>" --model <alias> --channel <id> --message <id> --initiator <x> --idempotency-key <k>` sets the model but has NO `--worktree`. So to honor worktree+explicit-model together: use the **CLI spawn with `--model`** and instruct the session to **create its own isolated worktree** (`git worktree add`, see [[shared-checkout-worktree-isolation]]) — verified working 2026-07-27 (opus-5, PR #8148). The daemon's build.ts `startBuild` supports worktree+model natively but isn't triggered from main. Clean fix = add `--worktree` to CLI spawn OR a `model` param to MCP `spawn_session` (proposed to Kevin). opus-5 alias = `claude-opus-5[1m]`; available 2026-07-27.

**Before setting an unavailable model as the fleet default, PROBE it** (`claude --model claude-fable-5 --print "ok"`) — an unavailable model at launch crash-loops every spawn (no fallback in `session-lifecycle.ts` launch). Fable was globally unavailable Jun 12–~Jul 1 2026 (export-control directive); confirmed available again 2026-07-08.