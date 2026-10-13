---
name: raindrop-query-mcp-access
description: Raindrop AI has its own MCP server for querying events; needs a Query SDK key, and Kevin's org role may gate creating one
metadata:
  type: reference
---

Raindrop AI (the observability product) ships an MCP server at `https://mcp.raindrop.ai/mcp` (HTTP transport). Not configured in `~/.claude.json` as of 2026-09-21.

Auth is OAuth 2.1 or `Authorization: Bearer <key>` — and it needs a **Query SDK** key, which is a *different* credential from the `RAINDROP_WRITE_KEY` used for ingestion. Generated at app.raindrop.ai under settings → API Keys → Query SDK → Manage API keys. The header format is strict; stray whitespace fails auth rather than degrading.

Two gotchas found while trying this:
- Searching for "raindrop MCP" mostly returns **raindrop.io**, an unrelated bookmarking app with several community servers. Wrong product.
- Clicking "Manage API keys" landed on the AngelList org **Users** page, where Kevin is a `Member` and the Owners are tian.wang and thibaut. Key creation is plausibly owner-gated — unresolved. `AI Integrations` in that console's sidebar was the untried candidate.

Useful tools it exposes: `get_event_timeseries`, `get_event_facets` (group-by), `get_event_count`, `search_events`, `get_dashboard`. **There is no dashboard-write tool** — charts cannot be created via MCP, only read. Kevin prompts dashboard creation in the raindrop.ai UI directly instead.

Relevant for verifying [[raindrop-usage-live]] figures against what actually landed, rather than against a local transcript replay.
