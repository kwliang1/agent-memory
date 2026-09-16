---
name: feedback-post-in-the-actual-thread
description: "When a task is about a specific Slack thread, post the answer IN that thread — don't just relay findings to Kevin in the bridge DM."
metadata: 
  node_type: memory
  type: feedback
  originSessionId: 1e4f5dcc-7268-4add-a6fb-d5591bed1953
  modified: 2026-07-24T06:42:03.538Z
---

When Kevin spawns me to research/validate something tied to a specific Slack thread (e.g. "validate my response <thread link>"), the deliverable is a reply **posted into that Slack thread** via `slack_send_message` (thread_ts = parent ts) — not just a report relayed to him in the bridge DM.

**Why:** He asked me to "reply in slack" after I spent the whole investigation reporting only in the bridge and merely *offering* to draft the thread reply. Offering instead of doing = stalling.

**How to apply:** Do the research + report progress in the bridge as usual, but when the ask centers on a thread, actually post the finished answer to that thread (professional voice, as Kevin's account — drop the Russell flavor for public eng channels). It posts under his identity, so keep it accurate and in his tone. Confirm the link back to him in the bridge. Public-channel posts are outward-facing but his direct instruction to reply there is the authorization. Related: [[bridge-is-slack]], [[reply-chat-id-must-be-thread]].
