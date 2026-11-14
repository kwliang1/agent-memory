---
name: slack-thread-titles-agents
description: Slack thread titles need the Agents feature; rename works only after agents.sessions.setStatus creates the session (shipped in hydra #474)
metadata:
  type: project
---
Slack's native "Thread" header can only be titled via the Agents & AI Apps feature. Probed on the hydra bot (AngelList Enterprise Grid, bot U0BD78J1M9C) against a DM thread:
- `agents.sessions.rename` (needs only chat:write, documented for "thread-based sessions in regular channels and DMs") → `not_authorized` = app is not an agent for the session. Not `feature_disabled`, so the workspace likely allows it.
- `assistant.threads.setTitle` (deprecated in favour of the above) → `missing_scope`, needs `assistant:write`.
- Current bot scopes have no assistant:write. Unblocking it means turning Agents on in the app config, adding the scope, and reinstalling, which an Enterprise admin may have to approve.
- `SlackGateway.updateSessionVisual` is a no-op (slack-gateway.ts ~775); set_description never reaches Slack.

**Why:** Kevin wants the session name and description locked in the thread header.
**How to apply:** once the app is an agent, wire rename into updateSessionVisual. Before that, check how Agents mode changes top-level DM messages for the main session (Slack auto-groups DM conversations into threads).

**State 2026-10-23:** Agent experience toggled ON at api.slack.com/apps/A0BDB5R333K/app-assistant and assistant:write appears in the scopes. The reinstall is gated: "Request to Workspace Install" needs AngelList admin approval, and Kevin is asking an admin himself. After approval and reinstall, re-probe agents.sessions.rename on a DM thread, then run the DM-UX spike before wiring updateSessionVisual.

**Agents unlocks (from the docs, 2026-10-23):** agents.sessions.setStatus (processing/active/suspended/closed, which shows a loading indicator; needs chat:write), agent_session_stopped (stop button → interrupt), chat.start/append/stopStream, assistant.threads.setSuggestedPrompts, agent_session_title_changed, app_context_changed (split view), and code channels (agents.conversations.*, needs the code_channels:manage scope; may be Enterprise-restricted). Recommended to Kevin: ship titles + setStatus + stop together. NOT an MCP migration: the Slack MCP Server toggle stays off.

**Decisions (Kevin, 2026-10-23):** NO stop button (don't subscribe to agent_session_stopped). Wants PR states in the title (in review / approved-needs-deploy) via pr-watch. Code channels PUNTED: did not add code_channels:manage. Docs say they're a distinct UI (tab views, context bar, origin card), but the cost is re-keying sessions off channel:thread_ts, and availability on Grid is unknown.

**Reinstalled + re-probed 2026-10-26:** the token now has assistant:write. assistant.threads.setTitle → ok. agents.sessions.rename stays not_authorized until agents.sessions.setStatus creates the session (status active → ok, warns missing_agent_session_stopped_event_subscription, which is expected since there's no stop button), then rename → ok. The title validator rejects ':' and '·' (invalid_name) but allows emoji and '-'.

**Shipped:** hydra #474 (merged 2026-10-26) sets titles and status on Slack through a dedicated WebClient and ThrottledQueue. Follow-ups: PR states in titles via pr-watch, and probing a shared-channel thread.
