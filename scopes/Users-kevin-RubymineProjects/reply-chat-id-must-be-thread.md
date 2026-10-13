---
name: reply-chat-id-must-be-thread
description: "reply tool chat_id must always be the thread chat_id, never a message_id — mis-addressing scatters replies where Kevin can't see them"
metadata:
  node_type: memory
  type: feedback
  originSessionId: ba5fea11-0724-48e0-bbfb-a28b4c427090
  modified: 2026-09-24T19:07:34.709Z
---

Always pass the **thread chat_id** (e.g. `D0BE3RB4Y00:1783554752.069799`) as `reply`'s `chat_id`. To quote-reply a specific message, use the separate `reply_to` param — NEVER put a message_id/ts in `chat_id`.

**Why:** 2026-07-09, mid-thread I addressed several `reply` calls with Kevin's message timestamps as `chat_id` (e.g. `1783569081.736399`). Each returned "sent," but they posted as replies pinned under individual messages instead of the main thread flow, and Kevin said "I don't see your replies in slack." Re-sending to the correct thread chat_id fixed it immediately.

**How to apply:** The inbound `<channel chat_id="...">` on Kevin's messages shows the thread chat_id — reuse exactly that for every reply. A "sent" result confirms the tool call, NOT that it reached his view. If Kevin says he can't see replies, check whether recent `chat_id`s were message-ids and re-post to the thread. See [[always-reply-via-tool]].

**Third failure mode — the suffix can be MISSING on a threaded message (2026-09-24):** Kevin replied "no" inside a session thread, but the inbound reached me tagged `chat_id="D0BE3RB4Y00"` with **no `:ts` suffix**. Taking the tag verbatim (correct per the rule above) sent my reply to the top-level DM, so it never appeared in the thread he was in — and I compounded it by asserting "this is the top-level DM, so a bare message lands on me," which was simply false. He had to tell me twice.

So a bare `chat_id` does **not** prove the message was top-level. When a reply is bare *and* the content reads like a fragment answering something you didn't ask ("no", "yes", "that one"), suspect a stripped suffix rather than assuming it was addressed to you. Confirm before answering: `slack_read_channel` on the DM with `oldest=<ts-60>` — if his message is absent from the top-level history, it was threaded and your reply needs the thread ts. Cheap check, and it beats answering the wrong conversation.

**Second failure mode (2026-09-10):** the same slip also breaks the bridge's reply watchdog. I passed `chat_id="D0BE3RB4Y00:1789084046.142169"` (a message_id). The reply *did* land in the thread that time and Kevin could read it — but ~3m later the bridge fired `[system] ⚠️ Reply check: the message ... has gone ~3m with no reply sent to that chat`, because it tracks delivery per chat_id and never saw one for the thread. So a mis-addressed reply can look doubly wrong: sometimes invisible to Kevin, sometimes visible but flagged as unanswered. Verify with `fetch_messages` on the thread before re-sending — a duplicate post is worse than the warning.

**Fourth cause, and it mimics the third (2026-09-27):** an *orphaned thread* — the session died or failed to re-register after a daemon restart — also delivers to main with a bare `chat_id`, while the daemon's `effectiveThreadId` is perfectly intact. I misread this as a stripped suffix and then blamed the wrong PR. Check the daemon log's `thread routing:` line for `mappedSession=none` before concluding anything. See [[hydra-restart-orphans-threads]].
