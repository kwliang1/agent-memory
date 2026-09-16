---
name: rtl-pr-bump-automation
description: The bump-stale-rtl-prs skill + how to schedule PR-bump reminders; cloud-routine env has Slack MCP but NO gh/GitHub access.
metadata: 
  node_type: memory
  type: project
  originSessionId: c7bad37a-2285-489a-8ff6-756386ac9602
  modified: 2026-08-20T18:13:13.682Z
---

Kevin wants stale RTL review PRs auto-"bump"ed in Slack. Built 2026-08-20.

**Skill:** `~/.claude/skills/bump-stale-rtl-prs/SKILL.md`. Logic: scan the 3 RTL review channels for Kevin's own PR-share posts; for any 12+ hrs old with NO human review (no approval, no non-bot comment, no changes-requested — Cursor/Devin/DepthFirst bots DON'T count) reply `bump` once (idempotent — checks thread for existing `bump` first). RTL channel IDs: **C0AH06C1RPX, C0BMTCJJPUH, C07U3EXQ996**. Runs precisely ONLY when invoked LOCALLY (needs `gh` for review state, which exists in a local session, + AngelList-Slack MCP).

**One-time routine for #8120/#31124:** `trig_01W9aFnSjc85exvLXhwxeeQc` (cloud, RemoteTrigger), fires 2026-08-21T17:00:00Z (10am PT). Reads thread C0BMTCJJPUH ts `1787186010.749929`, posts `bump` unless already present. Kevin's thread: https://angellist.slack.com/archives/C0BMTCJJPUH/p1787186010749929

**RESOLVED via GitHub MCP connector (2026-08-20):** Kevin connected the **AngelList-Github** connector (connector_uuid `9343aec6-625b-4533-a362-5c9dec9e310d`, url `https://angellist.runlayer.com/api/v1/proxy/1be6b027-3747-4a24-af40-953ee9c27ccc/mcp`). Routine trig_01W9aFnSjc85exvLXhwxeeQc UPDATED to check approval precisely via `mcp__AngelList-Github__pull_request_read` (method get_reviews/get) + fallback "can't-determine → treat as unapproved → bump". So cloud routines CAN now check GitHub via the connector (NOT gh CLI, still absent). Approved = a review with state APPROVED by a human that is NOT a bot AND NOT the author `kwliang1`; a COMMENTED review (e.g. dcetlin on #8120) is NOT approval.

**KEY GOTCHA (historical) — cloud CCR routine env ("KL Test Treasury" env_01EDNde52NTX7iFsBGLnbXoz) has NO gh CLI + repo-source 403:** `gh` is `command not found`, adding a repo source 403s. So headless GitHub access must go through the **GitHub MCP connector** (above), not `gh`. Slack via AngelList-Slack connector works headless (tools `mcp__AngelList-Slack__slack_read_thread`/`slack_send_message`, verified via [probe] 2026-08-20).
  - Cloud-routine create shape: `RemoteTrigger action:create`, `run_once_at` RFC3339 UTC (future), `job_config.ccr.{environment_id, session_context:{model,allowed_tools,sources?}, events:[{data:{uuid(lowercase v4), session_id:"", type:"user", message:{role,content}}}]}`, `mcp_connections:[{connector_uuid, name:"AngelList-Slack", url}]`. AngelList-Slack connector_uuid = `f40e3259-d098-4264-9a33-43f513e50848`. Slack MCP tool names in cloud = `mcp__AngelList-Slack__slack_read_thread` / `slack_send_message` etc. (confirmed working). Source-less create works; a repo source 403s in this env.
