---
name: hydra-respawn-inherits-model
description: "hydra respawn/resume reuse the dead session's model, not HYDRA_MODEL — a thread first spawned on an old model stays on it; use `respawn <alias>` or in-pane `/model opus[1m]`"
metadata:
  node_type: memory
  type: reference
  originSessionId: 4adcf8aa-2579-40b2-88cd-afb331a01c09
  modified: 2026-10-01T17:52:22.874Z
---

`respawn` (`hydra/daemon/commands/thread.ts:451`) and `resume` (`:334`) take the dead session's model via `recoveryModel(lastSession?.model ?? sessionMetadata.model)`. Only fresh spawns read `HYDRA_MODEL` (`session-lifecycle.ts:790`). Found 2026-10-01: after HYDRA_MODEL moved to `claude-opus-5-5[1m]`, respawned pixel came back on opus-5.

To move a live or respawned session: send `/model opus[1m]` then `/effort medium` to its pane. The full id `claude-opus-5-5[1m]` fails with "Unable to validate model". A big-cache session shows a "Switch model?" confirm that needs Enter. Both commands also save as the default in `~/.claude/settings.json`. To respawn on a model: `respawn opus`.

Kevin declined a code fix (a modelExplicit flag) on 2026-10-01. Don't re-propose it unprompted.
