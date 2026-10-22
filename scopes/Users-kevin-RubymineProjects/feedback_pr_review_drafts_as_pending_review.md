---
name: feedback-pr-review-drafts-as-pending-review
description: When Kevin reviews someone else's PR, post the drafted comments to that PR as a pending (unsubmitted) review so he edits them in context; chat drafts are the fallback
metadata:
  type: feedback
---

When drafting Kevin's review comments on a colleague's PR, put them on the PR as **pending** review comments by default, anchored to the diff lines. He reviews and submits them himself.

**Why:** he asked for this five times in a week instead of reading chat drafts:
- "post the drafts to the PR as drafts, for my review in context" (3569d051, treasury #9139, 10-14)
- "post the drafts to the PR, (as drafts) for my review" (3eb945e1, 10-19)
- "post directly to this PR in draft alongside my pending review comments" (c60a9fbe, nova, 10-19)
- "post the comments on 1680 in draft for my review" (19455a69, ipseity, 10-20)
- "draft it directly in the PR for my review" (79890596, 10-20)

**How to apply:** a pending review is invisible to the author until Kevin submits it, so posting one doesn't count as replying to a human (the CLAUDE.md gate). Never submit it, and never use `event`. If he already has a pending review open, add to it instead of creating a second one. The API recipe is in [[github-pending-review-comment-edits-need-graphql]]. Order the comments as [[feedback_pr_comments_in_diff_order]] says. This applies to new review comments only. Replies in an existing human thread are still chat drafts until he approves them.
