---
name: hydra-cancelled-protocol-stale-nudges
description: "A cancelled adversarial review keeps emitting 'protocol did NOT advance' nudges after it is dead — advance() returns 'no active protocol'; don't chase them"
metadata:
  node_type: memory
  type: reference
  originSessionId: fb2c3e87-3f79-4685-8cab-fd7094f08e48
  modified: 2026-09-29T22:56:50.229Z
---

After Kevin cancels an adversarial review ("cancel the review" / "cancel the gate"), the bridge
keeps injecting this system line on **every** subsequent `reply()`:

> `[system] Your last post was sent via reply() — the protocol did NOT advance.`
> `If that was your deliverable, repost using advance({ content: "..." })`

**It is stale.** Calling `advance()` at that point returns a hard error:
`advance failed: no active protocol for this session`. The cancel already tore the protocol down;
the nudge generator doesn't know. Observed firing 3+ times across ~90 min on 2026-09-29.

**How to handle it:** verify once with a single `advance()` call — the error is definitive — then
ignore every later nudge. Do not re-post the deliverable through `advance()`, and do not tell Kevin
again after the first time: he cancelled it deliberately, and repeat explanations are noise in his
thread. Answer his actual question with `reply()` and move on.

Related trap in the same protocol: `advance()` rejects a `verdict` argument during the
`owner_turn` phase (`phase "owner_turn" does not accept a verdict`) — call it with `content` only.

See [[hydra-raindrop-session-id-mismatch]].
