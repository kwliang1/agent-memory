---
name: reply-tool-param-is-text
description: "The discord/Slack reply tool's message param is `text`, not `message` — wrong key fails with \"undefined is not an object (evaluating 'text.length')\"."
metadata: 
  node_type: memory
  type: reference
  originSessionId: 5558f86e-0b9b-450e-8079-44f0e39fca21
  modified: 2026-07-29T22:55:53.630Z
---

`mcp__plugin_discord_discord__reply` (the `reply` tool) requires the message body under **`text`**, not `message`. Passing `message` throws `reply failed: undefined is not an object (evaluating 'text.length')` — a JS error inside the tool, NOT a bridge/delivery failure, so don't misdiagnose it as [[disconnected-live-sessions-bridge-death]]. Schema: `{ chat_id, text, reply_to?, files? }`. Burned 3 calls on this once. Related: [[always-reply-via-tool]], [[reply-chat-id-must-be-thread]].
