---
name: eyeballs-ack
description: React with 👀 to ack a bridge message — but reactions are DISABLED on Slack, so send a fast text ack instead
metadata:
  node_type: memory
  type: feedback
  originSessionId: 17e0b963-d148-4cdf-ab88-58e767c74903
  modified: 2026-09-21T20:10:07.767Z
---

When Kevin sends a message over the bridge, acknowledge it immediately — before the longer substantive reply lands.

**Why:** Kevin can't tell whether a silent gap means you're working or stuck. He explicitly called this out (2026-07-21) after a daemon hiccup left him with no ack ("why are you not reacting with the eyeballs emoji to ack?").

**How to apply — the mechanism depends on the platform:**
- **Slack (the live bridge — see [[bridge-is-slack]]): the `react` tool is a no-op.** Calling it returns literally `no-op on Slack (reactions disabled)`. Verified 2026-09-21. So 👀 never reaches him there. When a task will take more than a moment, send a short `reply` ("on it — <one line>") as the ack, then the full answer later.
- **Discord:** `react` with 👀 works as originally described.

If the bridge daemon is down (`react`/`reply` return "not connected to daemon"/"daemon connection lost"), stop retrying after ~2-3 attempts (don't grind) and fire the ack + reply the moment it reconnects. See [[bridge-outbound-dead-curl-fallback]].
