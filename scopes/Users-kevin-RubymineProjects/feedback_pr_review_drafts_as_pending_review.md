---
name: feedback-pr-review-drafts-as-pending-review
description: When Kevin reviews someone else's PR, post the drafted comments to that PR as a pending (unsubmitted) review so he edits them in context; chat drafts are the fallback
metadata:
  type: feedback
---

When drafting Kevin's review comments on a colleague's PR, put them on the PR as **pending** review comments by default, anchored to the diff lines. He reviews and submits them himself.

**Why:** he wants to judge each comment against the code it sits on, not in chat ("post the drafts to the PR as drafts, for my review in context"). He asked for this five times in one week.

**How to apply:** a pending review is invisible to the author until Kevin submits it, so posting one doesn't count as replying to a human (the CLAUDE.md gate). Never submit it, and never set `event`. If he already has a pending review open, add to it instead of creating a second one. The API recipe is in [[github-pending-review-comment-edits-need-graphql]]. Order the comments as [[feedback_pr_comments_in_diff_order]] says. This covers new review comments only. Replies in an existing human thread stay chat drafts until he approves them.
