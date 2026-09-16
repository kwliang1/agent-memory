---
name: no-askuserquestion-on-bridge
description: "On the Slack/Discord bridge, never use AskUserQuestion — it renders as a UI modal the bridge doesn't relay, so it times out invisibly. Ask via the reply tool as plain text."
metadata: 
  node_type: memory
  type: feedback
  originSessionId: 0e543ade-488f-42be-95ee-8849ec3b5a75
---

The `AskUserQuestion` tool renders as an interactive modal in the Claude Code client UI. The Slack/Discord bridge only relays `reply`-tool messages, so an AskUserQuestion never reaches Kevin — it sits invisible and times out ("No response after 60s"), and I then proceed on "best judgment" for a decision he was never actually shown.

**Why:** same failure mode as [[always-reply-via-tool]] — the bridge carries only the reply tool, not other user-facing channels (transcript text, AskUserQuestion modals, ExitPlanMode prompts likely too).

**How to apply:** When on the bridge and I need Kevin to choose between options, ask via the `reply` tool as plain-text numbered options. Never call AskUserQuestion (or other UI-modal tools) expecting him to see them. (Exception: if Kevin has attached directly to the tmux/transcript, plain transcript text and possibly modals reach him — but default to reply-tool questions unless he says he's attached.)