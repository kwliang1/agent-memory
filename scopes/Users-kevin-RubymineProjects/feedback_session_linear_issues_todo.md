---
name: feedback-session-linear-issues-todo
description: "Linear issues created during a session (incl. follow-ups) go in Todo, not Backlog, and carry a summary of the design concerns"
metadata:
  node_type: memory
  type: feedback
  originSessionId: 1e5ba807-593f-4528-b160-c236181fc773
  modified: 2026-10-19T06:14:42.319Z
---

Issues I file for Kevin during a session, follow-ups included, get state **Todo**, not the team default of Backlog. Put a short summary of the design concerns discussed (e.g. idempotency) in each relevant issue body, not only in the arti plan.

**Why:** Kevin, 2026-10-18: "anything created this session can be explicitly TODO (instead of backlog)" and "add a summarized version of the idempotency concerns to the relevant linear issues".

**How to apply:** pass `state: "Todo"` on create. On Nova Foundations (BANK), moving to Todo auto-attached the current cycle, so check the cycle afterward and tell Kevin. Related: [[feedback_one_issue_per_item]], [[feedback_post_plan_to_linear]].
