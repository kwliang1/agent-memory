---
name: nova-datadog-log-facets-ui-only
description: "Datadog log facets aren't in ops/datadog-as-code and have no public API; check them via the UI-internal endpoint before shipping log tables that group by @attrs"
metadata:
  node_type: memory
  type: reference
  originSessionId: 6886af32-1b65-459a-b19e-f32808df9121
  modified: 2026-10-02T02:52:36.334Z
---

Log facets are NOT managed by `ops/datadog/` and Datadog has no public API to create them. A dashboard log widget that groups by a non-faceted `@attr` silently renders empty, and `sync.mjs` validation can't catch it.

- **List existing facets:** from a logged-in app.datadoghq.com tab, `fetch('/api/ui/event-platform/logs/facets').then(r=>r.json())` returns `facets.logs[].path` (no `@`).
- **Create:** Logs explorer → facet panel "+ Add" → path `@attr` → pick "New path" → Add. The first click on "+ Add" after a save is often swallowed; zoom to confirm the dialog is open before typing.
- **On 2026-10-01** none of nova's matchmaking attrs existed, including `@uploadId`, which #10674's dashboard already grouped by. Kevin approved creating 8: `uploadId, executionId, reason, errorClass, eventType, failurePhase, outcome, fsmNamespace` (BANK-2202, [[nova-matchmaking-fsm-observability]]).

**How to apply:** when a nova PR adds a log-table widget or a `group_by` on a log attribute, check the facet list first and tell Kevin which facets are missing.
