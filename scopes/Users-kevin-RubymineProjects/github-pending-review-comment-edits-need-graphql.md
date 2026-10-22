---
name: github-pending-review-comment-edits-need-graphql
description: Editing a comment inside a PENDING GitHub review 404s over REST; use GraphQL updatePullRequestReviewComment / addPullRequestReviewThread
metadata:
  node_type: memory
  type: reference
  originSessionId: 19455a69-88f2-45c7-8966-77f32c1f0d78
  modified: 2026-10-20T17:26:00.610Z
---

Drafting review comments for Kevin as a pending (unsubmitted) review:
- Create: `POST repos/{o}/{r}/pulls/<N>/reviews` with `comments[]` and no `event` → state PENDING. Only one pending review per user; if Kevin already started one, POST fails, so add to his instead with GraphQL `addPullRequestReviewThread(pullRequestReviewId: <PRR_ node id>, path, line, side: RIGHT, body)`.
- Edit: REST `PATCH pulls/comments/<id>` returns 404 for pending comments. Use GraphQL `updatePullRequestReviewComment(pullRequestReviewCommentId: <PRRC_ node_id>)`.
- Delete: REST `DELETE pulls/comments/<id>` works on pending comments.
- zsh doesn't word-split `$var` in `for x in $ids`; loop explicitly.

pr-watch echoes the pending review and, after submit, every comment back as "new feedback"; it's Kevin's own text, so there's nothing to triage. See [[pr-watch-phantom-pings]].
