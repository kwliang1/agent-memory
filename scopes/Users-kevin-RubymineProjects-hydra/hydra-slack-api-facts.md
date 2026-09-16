---
name: hydra-slack-api-facts
description: Live-verified Slack conversations.history/replies semantics for message lookup — the facts the docs get wrong
metadata: 
  node_type: memory
  type: reference
  originSessionId: d9380142-3df6-4689-9e54-52d39643be52
  modified: 2026-09-14T18:56:18.010Z
---

Verified 2026-09-14 by read-only `curl` against Kevin's real workspace (channel `D0BE3RB4Y00`, a 105-message thread), while fixing the thread-attachment wrong-file bug. **The published docs do not describe some of this** — a reviewer reasoned from docs and produced a false blocker.

- **`conversations.history` excludes thread replies.** With `latest=<a thread reply ts>` it returns the newest *channel-level* message at or before that ts — a different message, with that message's files. This was the wrong-file bug.
- **`conversations.replies` always prepends the thread parent**, outside any window. `limit` counts *replies*, not total rows: `limit=1` returns `[parent, target]`, not `[parent]`. Confirmed on reply #37 of 105 and on the first reply. So `.find(m => m.ts === messageId)` is required, not decoration.
- **`oldest == latest` + `inclusive: true` pins the result to exactly one timestamp.** For a top-level message `history` returns `[X]`; for a thread reply it returns **zero rows** rather than a substitute. `replies` returns `[parent, X]`, and `[parent]` alone when the target is the parent itself.
- **`inclusive: true` is load-bearing** — drop it from a pinned window and you get zero rows.
- **The post-2025-05-29 non-Marketplace limit of 1 req/min on `conversations.history`/`replies` does NOT apply to this app.** Tested with a 5-request burst: all `200`. Don't let a reviewer block on it.

**Why:** re-deriving this costs a live round trip against a workspace, and reasoning from the docs alone produces wrong conclusions in two directions.

**How to apply:** when looking a single message up by timestamp, pin the window and match the ts exactly — never trust row order or position. Bot messages never reach the lookup: the Slack handler drops them (`subtype === 'bot_message'`, and a guard requiring a top-level `user`, which also drops `message_changed`).

See [[hydra-attachment-followups]] for the fix that came out of this and [[hydra-slack-setup]] for the bot's config.
