---
name: feedback-index-lines-no-status
description: "Memory index lines carry the durable lesson, never ephemeral state (PR open/merged, \"not yet run\", \"unfixed\"); status lives in the memory file, dated."
metadata:
  node_type: memory
  type: feedback
  originSessionId: ce5b2ae7-df5e-4919-a9c6-44d68e1ca2d6
  modified: 2026-10-14T23:21:56.159Z
---

Index lines (MEMORY.md, CATALOG.md) state the lesson only. No PR state, "DONE", "awaiting X", "unfixed", "superseded" markers. A status belongs in the memory file body as a dated line. Exception: a do-not-run warning, phrased as a warning without status.

**Why:** Kevin, 2026-10-14: "should we ever reference PR statuses at all? Aren't they ephemeral". On that day, 5 of 8 status claims checked in the treasury/nova indexes were wrong (PRs marked open had merged).

**How to apply:** when writing or editing an index pointer, strip state words. Check `gh`, Linear or prod for current state instead of trusting a file. Related: [[hook-context-10k-cap]].
