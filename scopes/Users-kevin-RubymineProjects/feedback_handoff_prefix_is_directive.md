---
name: feedback_handoff_prefix_is_directive
description: A bridge message starting with "handoff:" is a directive to hand the thread to a fresh session — not message content
metadata:
  type: feedback
---

On 2026-10-08 Kevin sent two messages prefixed `handoff:` and I treated the rest as instructions to continue, twice. He had to ask "what happened to my handoff directive" and noted my context window was too large.

**Why:** `handoff:` asks this session to end and pass the thread to a fresh, small-context successor (the bridge's `handoff` tool), usually because context has grown too big.

**How to apply:** on any inbound message starting with `handoff:`, immediately write a handoff markdown (Goal, State, open questions, how to run things, Next action — folding in whatever the rest of the message asks), then call the discord `handoff` tool with its path. Do not keep working in the current session first.
