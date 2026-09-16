---
name: todo-design-autospawns-session
description: "OPEN TODO — when `design` is invoked from the main thread, spawn a dedicated session for it instead of working inline in main."
metadata: 
  node_type: memory
  type: project
  originSessionId: 0e543ade-488f-42be-95ee-8849ec3b5a75
---

**Open action item** (2026-07-02). When a `design` request comes in on the main bridge thread, it should **spawn a dedicated session** (`spawn_session`) for that design work — not run inline in `main`. Main is the bridge/dispatcher; design efforts belong in their own session with their own tmux thread to attach to.

Relates to [[todo-fix-unresponsive-on-bridge]] (the inline-in-main design was a root cause of the unresponsive episode).

Implementation note: an automatic "when `design` invoked → spawn session" behavior is a harness hook, not something I can enforce by intention alone (see update-config skill for settings.json hooks).