---
name: hydra-raindrop-session-id-mismatch
description: "Raindrop keys hydra usage on claudeSessionId (the provider id), NOT the session_id the spawn message announces — searching the announced id finds nothing"
metadata:
  node_type: memory
  type: reference
  originSessionId: fb2c3e87-3f79-4685-8cab-fd7094f08e48
  modified: 2026-09-29T17:54:46.154Z
---

A spawned hydra session is announced with a `session_id` (e.g. `b067e7ed-…`) that **does not appear
anywhere in Raindrop**. The `hydra.session.usage` events store `claudeSessionId` /
`providerSessionId` = the *Claude Code* session id (e.g. `fb2c3e87-…`), which is also the name of
the session's scratchpad dir and its transcript file under
`~/.claude/projects/<slug>/<claudeSessionId>.jsonl`. Nothing in the event cross-references the
hydra id, so a search by the announced one returns zero and reads as "usage isn't being captured."

Find a session's usage in project **`default`** (Production) by `tmuxName`, `threadId`, or `repo`:

```
mcp__raindrop__get_event_count(project:"*", event_name:"hydra.session.usage",
  properties:[{key:"threadId", op:"eq", value:"<D0…:…>"}])
```

Useful properties on each event: `cumulative{Input,Output,CacheRead,CacheCreate}Tokens` and the
matching `delta*`, `model`, `repo`, `tmuxName`, `originType`, `sessionType`, `coldStart`.

**The cumulative counters cover the main session only — subagent usage is NOT in them.** See
[[review-gate-cache-cost-accounting]] for how far off that puts a cost estimate.
