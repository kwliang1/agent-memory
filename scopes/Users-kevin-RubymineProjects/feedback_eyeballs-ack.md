---
name: eyeballs-ack
description: React with 👀 to ack a Slack/Discord message the moment you pick it up
metadata: 
  node_type: memory
  type: feedback
  originSessionId: 17e0b963-d148-4cdf-ab88-58e767c74903
---

When Kevin sends a message over the Slack/Discord bridge, react to it with the 👀 emoji (via the discord `react` tool) as an immediate acknowledgement that you've seen it and started working — before the longer substantive reply lands.

**Why:** Kevin can't tell whether a silent gap means you're working or stuck. The 👀 reaction is a cheap, instant "got it, on it" signal. He explicitly called this out (2026-07-21) after a daemon hiccup left him with no ack ("why are you not reacting with the eyeballs emoji to ack?").

**How to apply:** On picking up a new inbound message, first `react` 👀 to that message_id, then do the work and `reply`. If the bridge daemon is down (`react`/`reply` return "not connected to daemon"/"daemon connection lost"), stop retrying after ~2-3 attempts (don't grind) and fire the ack + reply the moment it reconnects.
