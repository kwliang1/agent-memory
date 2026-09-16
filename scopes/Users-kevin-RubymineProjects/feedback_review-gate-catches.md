---
name: review-gate-settings
description: "Review agent settings -- opus model, high effort; address Devin/Cursor feedback; reply to PR threads with fix links"
metadata: 
  node_type: memory
  type: feedback
  originSessionId: 021ac3c2-b0c1-4819-a048-9574a5a80dda
---

Review agent configuration:
- Always `model: "opus"` with high effort for reviewer agents
- External AI reviewers (Devin, Cursor) catch things internal agents miss -- always poll and address their feedback
- Always reply to every external reviewer comment (real bug or false positive) and resolve the thread -- never leave them unanswered
- Reply to each PR review comment thread with the commit link where it was fixed (or false positive reasoning)
- When fixing, batch all fixes into one amend + push, then reply to all threads at once
