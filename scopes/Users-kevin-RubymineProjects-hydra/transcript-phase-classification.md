---
name: transcript-phase-classification
description: "Measured facts for classifying transcript windows into plan/execute/review phases, and the dedup trap that inflates hand-rolled token counts ~3x"
metadata:
  node_type: memory
  type: project
  originSessionId: ee84b05e-77f7-49e3-9208-24e2481b8da9
  modified: 2026-09-26T20:56:28.052Z
---

Design work on 2026-09-26 (session atlas, unbuilt as of writing) for putting a `phase` property on `hydra.session.usage`. These are measured over `~/.claude/projects`, not inferred:

**A per-window tool-name rule collapses at raindrop's tick length.** `Agent`→review / `Edit|Write`→execute / else→plan gives plan 61% at hourly windows but **plan 98.2% / review 1.1%** at the live 60s tick, because most minutes carry neither tool and the catch-all takes them (`Bash` alone is 15,477 of 20k+ fleet tool calls and falls to plan). **Latching the phase across windows** — a toolless window keeps the previous phase — gives review 80.6% on the same session, and review 62% / execute 26% / plan 13% fleet-wide once subagents are counted. Any future phase work should start from the latch, not from per-window classification.

**Counting tokens without the per-message dedup inflates by ~3x.** Each assistant turn writes one line per content block and every line repeats the whole `message.usage` envelope (e.g. 141 usage lines, 31 unique `message.id`). `daemon/usage.ts` dedups on `message.id`; hand-rolled scripts usually don't. Consecutive-only dedup and global-set dedup give identical totals, so the cheap check is correct. Any figure quoted from a one-off transcript script should be re-derived with the dedup before a PR cites it.

**Subagent transcript layout** (never read by the daemon; see [[raindrop-usage-live]] for the exclusion): `<projectsRoot>/<dir>/<sessionId>/subagents/agent-<id>.jsonl`, each with an `agent-<id>.meta.json` sidecar carrying `agentType`, `description`, `toolUseId`, `spawnDepth`, `parentAgentId`. The dir is **flat** — depth-2 agents sit beside depth-1, so no recursion. Lines are `isSidechain: true` and carry the *parent's* `sessionId`. A parent has zero sidechain lines and zero `message.id` overlap with its subagents, so parent↔subagent double-counting is not possible. Largest real dir seen: 198 transcripts. The parent's `Agent` tool_use `input.subagent_type` gives the same signal without opening the sidecar.

**`Task` does not exist in this fleet** — the tool is named `Agent` (1,124 calls vs 0). `NotebookEdit`: 0.
