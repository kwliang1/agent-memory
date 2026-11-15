---
name: sentry-mcp-cannot-delete-cron-monitors
description: The Sentry MCP connector has no whole-cron-monitor delete; only delete_monitor_environment
metadata:
  type: reference
---

The Sentry MCP (both `mcp__sentry__*` and the claude.ai AngelList Sentry connector) can list and inspect cron monitors but cannot delete one — only `delete_monitor_environment`, which leaves an empty monitor behind. A real delete needs the REST API (`DELETE /api/0/organizations/{org}/monitors/{slug}/`) with a token; `sentry-cli` on this machine was unauthorized and `sentry-cli login` didn't work for Kevin (2026-10-27).

**Why:** BANK-2384 left 105 stale treasury cron monitors (every one mapped to a Temporal schedule or deliberate removal); Kevin OK'd deletion but it stalled on tooling.
**How to apply:** Don't promise an MCP-driven cron-monitor delete. Ask Kevin for a token up front, or hand him the list for the Crons UI.
