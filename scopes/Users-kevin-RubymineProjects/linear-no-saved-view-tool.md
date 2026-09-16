---
name: linear-no-saved-view-tool
description: "Linear MCP can't create saved/custom views; use a shared issue label as the filterable-set workaround."
metadata: 
  node_type: memory
  type: reference
  originSessionId: e4ff4581-f090-474c-a221-dbd4f50b6e86
  modified: 2026-07-28T19:29:39.482Z
---

The AngelList Linear MCP has no tool to create a saved/custom view (no `save_view`; `create_view` is Notion-only). To give Kevin a "just these N issues" view, apply a shared **issue label** to the batch (`create_issue_label` with `teamId`, then `save_issue` `labels:[...]` on each — note `labels` REPLACES the full set), then he filters by that label in the UI and clicks **Save view**.

Nova Foundations team id = `85472f66-2626-4a5d-9335-15a9d188a4df` (key `BANK`). Assignee accepts email. Cross-ref [[nova-fund-onboarding-script]].

Pre-filtered URL that MAY work (Linear's encoded-filter format drifts — verify before trusting): `https://linear.app/angellist/team/BANK/all?filter=<url-encoded {"and":[{"label":{"name":{"eq":"<label>"}}}]}>`. Bulletproof fallback: click the label chip on any ticket.

First use: 2026-07-28, labeled BANK-1717..1724 (Bank Eng Dashboard Review to-dos) with `dashboard-review-2026-07-28`.
