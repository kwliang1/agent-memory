---
name: fenced-commands-never-route
description: "Wrapping ANY hydra router command in a ``` code fence silently kills it — the message falls through to the main session as plain text and nothing spawns. Bit Kevin twice on 2026-09-14/15."
metadata:
  node_type: memory
  type: reference
---

**Every hydra router command is prefix-anchored. A leading ``` fence breaks the match and the command silently does nothing** — no error, no reaction; the text is just delivered to the main session as an ordinary message.

Two hits in two days, different commands, same cause:
- `respawn astra` + a trailing fenced block → `RESPAWN_RE` is `$`-anchored, never matched (see [[respawn-must-be-in-a-thread]]).
- ```` ```factory: BANK-2095 … ```` → template spawn never fired; sat dead ~70 min.

**Template spawns** (`factory:`, `review:`, `fix:`, `investigate:`) resolve at `daemon/router.ts:563-565`:

```js
const candidateName = msg.content.slice(0, colonIdx).trim().toLowerCase()
const template = getTemplate(candidateName)
```

The prefix becomes `` ```factory ``, and `getTemplate` returns null. Verified:

```
getTemplate("factory")     -> FOUND  sessionType=master_orchestrator
getTemplate("```factory")  -> null
```

**Diagnosing it:** if a command message reaches me at all, it was NOT intercepted — the router consumes what it handles. A reply-check warning about an unanswered command message is the tell.

**Multi-line is fine unfenced.** Template topics take `msg.content.slice(colonIdx + 1)` — everything after the FIRST colon, newlines included. Only the leading fence is fatal. Same for `respawn <alias>: <topic>`.

**A second guard on template spawns:** they're skipped entirely when a live session already holds the thread (`router.ts:561`, `if (!liveInThread)`). Check with `jq '.[] | select(.threadId=="<thread>")'` on `sessions.json` before telling Kevin to re-paste — no rows means it's clear.

**I cannot fire these myself.** `spawn_session` (the MCP tool) takes no `template` param, so a `master_orchestrator` factory session with its `Edit`/`Write` restrictions can only come from Kevin's own message. Same structural gap as the codex engine ([[hydra-codex-sessions-gotchas]]): hand him the exact un-fenced text to paste rather than substituting a plain session.
