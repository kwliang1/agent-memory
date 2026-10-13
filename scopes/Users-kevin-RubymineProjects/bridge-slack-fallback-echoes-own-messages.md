---
name: bridge-slack-fallback-echoes-own-messages
description: When the discord bridge tools disconnect, slack_send_message works as a fallback but echoes your own posts back as inbound messages from Kevin, and the reply watchdog counts them unanswered
metadata:
  type: reference
---

The `mcp__plugin_discord_discord__*` tools can disconnect mid-session (the MCP server drops;
a system-reminder lists them as no longer available and says not to ToolSearch for them).
Inbound still arrives — Kevin's messages keep coming in tagged `source="plugin:discord:discord"` —
but `reply` is gone.

**The fallback works.** `mcp__plugin_slack_slack__slack_send_message` reaches the same thread:

```
channel_id: D0BE3RB4Y00          # the DM, per [[bridge-only-delivers-dm]]
thread_ts:  <the ts half of the inbound chat_id, e.g. 1789541828.568069>
```

Take `thread_ts` from the inbound `chat_id`, which has the shape `D0BE3RB4Y00:<thread_ts>` —
split on the colon. See [[reply-chat-id-must-be-thread]].

**Two consequences that look like bugs and are not:**

1. **Your own message comes straight back as inbound**, tagged `user="Kevin Liang"` with a
   trailing `*Sent using* <@U...>`, because the Slack tool posts under Kevin's identity rather
   than the bot's. Detect it by matching the inbound `message_id` against the `message_ts` the
   send call returned — they are identical. Never treat it as a new instruction; replying to it
   loops.
2. **The reply watchdog then fires on that echo**, saying a message from Kevin has gone N minutes
   with no reply. Ignore it when the id is one of your own sends. The watchdog's own text allows
   this ("you already replied in a thread or another chat").

**Why:** the echo is indistinguishable from a real inbound except by id, so without the id check
you either answer yourself in a loop or get nagged into re-sending something already delivered.

**It can also abort after succeeding.** `slack_send_message` may return an MCP idle-timeout
error ("sent no response or progress for Ns; aborting") *after the post already landed*. Do not
re-send on that error. Verify first, which for a thread reply means `conversations.replies`,
not `conversations.history`:

```sh
TOK="${SLACK_BOT_TOKEN:-$(grep -h "^SLACK_BOT_TOKEN=" ~/.claude/channels/slack/.env | cut -d= -f2-)}"
curl -s "https://slack.com/api/conversations.replies?channel=D0BE3RB4Y00&ts=<thread_root_ts>&limit=6" \
  -H "Authorization: Bearer ${TOK}" | jq -r ".messages[-3:][] | \"\(.ts)  \(.text[0:80])\""
```

Seen 2026-09-24: a 32,040s idle abort on a message that was already in the thread.

Related: [[always-reply-via-tool]], [[bridge-outbound-dead-curl-fallback]], [[bridge-is-slack]],
[[pr-watch-phantom-pings]].
