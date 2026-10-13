---
name: feedback-one-issue-per-item
description: "When Kevin asks to track several follow-ups \"in a gh issue\", file one issue per item, not one combined issue"
metadata:
  node_type: memory
  type: feedback
  originSessionId: 3dca312f-c84e-4286-992d-bde6e50bac69
  modified: 2026-10-11T06:08:21.729Z
---

Kevin asked to "track both of these in a gh issue" (experiment selector + propose/A-B, daedalus 2026-10-10). I filed one combined issue; he corrected: "no, one issue per".

**Why:** each follow-up gets its own design, status and PR link; a combined issue can't be closed piecemeal.

**How to apply:** default to one GitHub issue per distinct follow-up, cross-linked, even when he says "an issue". Related: [[feedback-link-linear-issues-in-comments]].
