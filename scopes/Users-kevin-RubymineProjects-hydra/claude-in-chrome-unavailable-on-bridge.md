---
name: claude-in-chrome-unavailable-on-bridge
description: "OUTDATED as of 2026-07-27 — Claude-in-Chrome DOES work from the bridge session now. Probe with list_connected_browsers before assuming otherwise."
metadata: 
  node_type: memory
  type: reference
  originSessionId: 0e543ade-488f-42be-95ee-8849ec3b5a75
  modified: 2026-07-28T05:43:13.664Z
---

**UPDATE 2026-07-27: this no longer holds.** `mcp__claude-in-chrome__list_connected_browsers` returned a live local browser from the bridge session, and navigation, screenshots, `read_page`, `read_console_messages` and `javascript_tool` all worked against `angellist.dev`. Don't tell Kevin browser work is impossible here — **probe first** with `list_connected_browsers`.

Two caveats that do still apply: the tool contract says to confirm the browser choice via `AskUserQuestion`, which the bridge cannot render (see [[no-askuserquestion-on-bridge]]) — ask in plain text via `reply` instead, or proceed when exactly one local browser is connected and say which one you used. And a page behind Rails CSRF will 422 if you POST GraphQL by hand from `javascript_tool`.

The original (now superseded) analysis follows.

---

Claude-in-Chrome (mcp__claude-in-chrome__*) does NOT work from this bridge session. `tabs_context_mcp` returns "Browser extension is not connected" even after Kevin runs `/chrome`. Root cause: the extension bridges Chrome ↔ the Claude Code instance authenticated under the **same account**. This bridge runs as the dedicated **bot account** (CLAUDE_CONFIG_DIR=`~/.claude-byte`, token auth — see [[claude-config-topology]]), while `/chrome` pairs the extension to Kevin's **personal claude.ai** Chrome. Mismatch → the bot session is blind to Kevin's browser tabs regardless of reconnects.

Implication for any browser task (e.g. scraping authenticated docs like the Apex/ReadMe AscendOS API): it must run from **Kevin's own interactive Claude Code** (personal claude.ai account + his Chrome), not the bridge. Then hand the extracted output back to a bridge session for follow-on work. For authenticated API docs specifically, prefer getting the **OpenAPI/Swagger spec file** (one machine-readable doc) over browser-scraping entirely.