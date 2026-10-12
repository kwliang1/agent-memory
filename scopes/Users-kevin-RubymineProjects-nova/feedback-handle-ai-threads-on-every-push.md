---
name: feedback-handle-ai-threads-on-every-push
description: "Every push must end by sweeping both PRs for AI review threads, replying, and resolving them — not just the one Kevin happens to link"
metadata: 
  node_type: memory
  type: feedback
  originSessionId: b4bb1d9d-05e0-455a-a8d8-b73128746889
  modified: 2026-09-18T00:34:34.177Z
---

Said 2026-09-18 on BANK-2029, after I had fixed and resolved one Bugbot thread he linked me:
*"you should also reply and resolve AI feedback threads when pushing."*

**Why:** replying and resolving is part of pushing, not a separate task he should have to prompt. He
linked one thread; the expectation is that I find the rest myself. A bot thread left open reads as
ignored, and an unresolved thread on a stacked PR blocks the stack's check status.

**How to apply — run this after every push, on every PR in the stack, not just the one that
changed.** The GraphQL query is the authoritative view; the REST endpoints alone will not tell you
whether a thread is resolved:

```sh
gh api graphql -f query='query { repository(owner:"angellist", name:"nova") {
  pullRequest(number:NNN) { reviewThreads(first:30) { nodes {
    isResolved isOutdated comments(first:1){nodes{author{login} databaseId}} } } } } }' \
  --jq '.data.repository.pullRequest.reviewThreads.nodes[] | select(.isResolved==false)'
```

Then per unresolved bot thread: reply via
`gh api repos/angellist/nova/pulls/<N>/comments/<comment_id>/replies --method POST --input <json>`
and resolve with GraphQL `resolveReviewThread` (query the thread node id first — REST cannot
resolve). Bot/AI reviewers (Cursor Bugbot, depthfirst) are exempt from the human-reviewer approval
gate, so reply directly. **A human thread stays open until Kevin approves the reply text.**

Also check `/reviews` for review-level bodies: Cursor posts a summary review ("did not approve …
one potential issue") whose body cannot be resolved and goes stale after you fix the finding. That
is expected — resolving the inline thread is the mechanism; don't chase the summary.

Say what the fix was and how you proved it, in the reply. On BANK-2029 the finding was a real race
and the reply carried the demonstration: old helper red under a delayed mock, new helper green.

Related: [[feedback_pr_body_markers]], [[feedback-two-reviewers-per-round]].
