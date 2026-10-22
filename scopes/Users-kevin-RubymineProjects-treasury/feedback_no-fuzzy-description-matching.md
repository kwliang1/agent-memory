---
name: feedback_no-fuzzy-description-matching
description: "Don't detect records by fuzzy description/LIKE matching unless the string is a template the app itself writes; prefer a structural or outcome check"
metadata:
  node_type: memory
  type: feedback
  originSessionId: 37b7a3e7-3ba4-40cf-b4ec-765dfa625630
  modified: 2026-10-16T18:26:28.078Z
---

Kevin (2026-10-16, on a balance-check repair task): "description matches (fuzzy strings) should generally be avoided unless it's templated in the application logic."

**Why:** a guard that LIKE-matches "wire <id>" in descriptions missed bare ledger reversals ("…rejected OW <id>"), force_note-only legs and generic recon descriptions; mutation testing showed it leaky. Matching on app constants (e.g. `OutgoingWires::StateService::SVB_EXCESS_DESCRIPTION`) is fine because the app writes them.

**How to apply:** for "was this already fixed?" guards in repair tasks, check the outcome (e.g. the latest balance-check record still shows the diagnosed gap and is fresh) or a structural link (requester, idempotency token), not free-text descriptions. Related: [[project_balance-check-diagnosis-skill]].
