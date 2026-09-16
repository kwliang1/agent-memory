---
name: respawn-must-be-in-a-thread
description: "`respawn` only works inside a thread and only when the message is nothing but the command — a pasted code fence after the alias silently routes it to the main session as plain text instead."
metadata:
  node_type: memory
  type: reference
---

Two ways a `respawn` silently does nothing (both hit on 2026-09-14):

**1. It must be sent in a thread.** `handleRespawnIntercept` (`daemon/commands/thread.ts:393`) returns `'must be used in a thread'` when `!msg.isThread`. Sent in the top-level DM it is refused no matter how cleanly it's typed.

**2. The message must be ONLY the command.** `RESPAWN_RE` (`daemon/recovery-selection.ts:3`) is `$`-anchored:

```
/^(?:respawn|\/respawn)(?:\s+([a-z][\w.-]*))?(?:\s+((?:\+\w+\s*)+))?(?::\s*([\s\S]*))?$/i
```

Paste anything after the alias that isn't `: <topic>` — a stray ``` fence, a trailing block — and the anchor never lands, the regex fails, and the router delivers the whole thing to the main session as an ordinary message. No error is shown. `respawn` is also absent from `COMMAND_PREFIXES` (`daemon/router.ts:40-54`), so nothing else intercepts it either.

The `: <topic>` form DOES take multi-line content (`[\s\S]*` runs to `$`) — newlines and fences are fine once the colon is there.

**A bare `respawn <alias>` reuses the original thread topic**, it does not carry anything new: `resolvedTopic = topic || thread?.topic || 'respawned session'` (`thread.ts:430`). To hand the new session fresh context you must use the colon form — or just post the context into the thread afterwards as a normal message, which works identically and is easier to get right.

Respawn refuses while a live session holds the thread (`thread.ts:411-417`) — `kill` first. See [[hydra-codex-sessions-gotchas]].
