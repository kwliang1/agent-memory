---
name: reply-chat-id-must-be-thread
description: "reply tool chat_id must always be the thread chat_id, never a message_id — mis-addressing scatters replies where Kevin can't see them"
metadata:
  node_type: memory
  type: feedback
  originSessionId: ba5fea11-0724-48e0-bbfb-a28b4c427090
---

Always pass the **thread chat_id** (e.g. `D0BE3RB4Y00:1783554752.069799`) as `reply`'s `chat_id`. To quote-reply a specific message, use the separate `reply_to` param — NEVER put a message_id/ts in `chat_id`.

**Why:** 2026-07-09, mid-thread I addressed several `reply` calls with Kevin's message timestamps as `chat_id` (e.g. `1783569081.736399`). Each returned "sent," but they posted as replies pinned under individual messages instead of the main thread flow, and Kevin said "I don't see your replies in slack." Re-sending to the correct thread chat_id fixed it immediately.

**How to apply:** The inbound `<channel chat_id="...">` on Kevin's messages shows the thread chat_id — reuse exactly that for every reply. A "sent" result confirms the tool call, NOT that it reached his view. If Kevin says he can't see replies, check whether recent `chat_id`s were message-ids and re-post to the thread. See [[always-reply-via-tool]].

**Second failure mode (2026-09-10):** the same slip also breaks the bridge's reply watchdog. I passed `chat_id="D0BE3RB4Y00:1789084046.142169"` (a message_id). The reply *did* land in the thread that time and Kevin could read it — but ~3m later the bridge fired `[system] ⚠️ Reply check: the message ... has gone ~3m with no reply sent to that chat`, because it tracks delivery per chat_id and never saw one for the thread. So a mis-addressed reply can look doubly wrong: sometimes invisible to Kevin, sometimes visible but flagged as unanswered. Verify with `fetch_messages` on the thread before re-sending — a duplicate post is worse than the warning.
