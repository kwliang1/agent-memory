---
name: always-reply-via-tool
description: "On the Slack/Discord bridge, only the reply tool reaches Kevin — transcript text is invisible to him"
metadata: 
  node_type: memory
  type: feedback
  originSessionId: 77f6b237-62fa-41a6-80e3-a258759c9022
---

Every answer to Kevin **must** go through the `reply` tool (`mcp__plugin_discord_discord__reply`). Plain assistant text in my transcript is NEVER seen by him — the bridge only relays reply-tool calls.

**Why:** On 2026-06-26 I composed a full answer to "What's the spawn notification fix?" as ordinary output text and never called the reply tool. Kevin saw nothing and came back ~11h later with "I don't think you answered this bud." The work was wasted and looked like I ignored him.

**How to apply:** When responding to a bridge message, the substantive reply belongs in a `reply` tool call, not in narration. Before ending a turn that was supposed to answer Kevin, confirm I actually issued a `reply` (or `react`/`edit_message`) call. If a turn produces an answer but no reply tool call, that answer didn't reach him. See [[main-session-spawn-notifications]] and [[reply-chat-id-must-be-thread]].

**Recurred 2026-07-09 (twice in one session):** (1) addressed several replies to message-ids instead of the thread chat_id → scattered ([[reply-chat-id-must-be-thread]]); (2) in a tool-heavy turn (right after a `save_issue` call) I composed the full answer as transcript text and never called `reply` at all — Kevin: "not getting your replies again." **High-risk trigger: turns where I also make OTHER tool calls (Linear/Bash/etc.) — I compose the human answer as prose and forget the reply call.** Rule: any turn meant to answer Kevin MUST end with a `reply` to the thread chat_id, and I verify that before yielding.
