---
name: raindrop-usage-live
description: Per-session token usage ships to Raindrop live since 2026-09-21; the two query contracts and the caveats that make a naive chart wrong
metadata: 
  node_type: memory
  type: project
  originSessionId: ba670beb-ee07-4a9d-a248-a8daa78eb6e0
  modified: 2026-09-22T05:39:28.215Z
---

`hydra.session.usage` has been live to api.raindrop.ai since 2026-09-21 (PRs #358–#361, daemon `09e0b69`). Reading it correctly is not obvious:

- **Lifetime per session**: `LAST(cumulative*)` grouped by `claudeSessionId`. Never `SUM` — it is a running total.
- **Windowed spend**: `SUM(delta*)`. Never `LAST`.
- **`coldStart = 1` ticks have `delta* = 0` by design.** Filter them or a window starting mid-session under-reports.

**Do not chart raw token sums.** The four counters have very different unit costs, so a raw sum is dominated by cache reads and says nothing about money. Cost-weight instead: `0.1*cache_read + 1.25*cache_create + 1*input + Nx*output` (cache read ≈0.1× input, cache write ≈1.25×; the output multiplier is model-dependent — Opus is 5×). A long session's cache reads run ~370× its output tokens, which is caching working correctly, not a problem.

Known-excluded from every figure: Task sub-agent transcripts (under `<id>/subagents/`, 12.5% of fleet tokens but 29–43% on a session that delegates), headless workers, and the main orchestrator. Delivery is at-least-once, so a committed-but-timed-out POST lands twice. `repo: 'none'` is a real unattributed bucket (~40%), mostly sessions sitting at `SPAWN_CWD` itself, which is not a git repo.

Still open: Raindrop's rate limit is unconfirmed and there is no 429 handling — a 429 counts as a send failure and then retries, which is the wrong response. See [[raindrop-query-mcp-access]].
