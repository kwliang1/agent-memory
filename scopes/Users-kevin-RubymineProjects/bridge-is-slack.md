---
name: bridge-is-slack
description: Kevin interacts via Slack. The bridge plugin is labeled discord (plugin:discord:discord) but the human-facing side is Slack — Slack threads work.
metadata: 
  node_type: memory
  type: reference
  originSessionId: 0e543ade-488f-42be-95ee-8849ec3b5a75
---

Kevin uses **Slack**, not Discord. The bridge plugin is internally named `plugin:discord:discord` (channel `source="plugin:discord:discord"`, tools `mcp__plugin_discord_discord__*`), and session URLs are `angellist.slack.com`. Don't be misled by the "discord" labeling — treat this as Slack: Slack threads render and work (an earlier wrong guess was "Discord DMs can't have threads"). Reach Kevin only via the `reply` tool (see [[always-reply-via-tool]]).