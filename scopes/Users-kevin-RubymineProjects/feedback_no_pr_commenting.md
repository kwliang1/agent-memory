---
name: Don't post PR comments on the user's behalf
description: When PR review feedback is informational/answerable rather than code-actionable, do not propose or post a reply on Kevin's behalf — handle the code changes only.
type: feedback
originSessionId: d79a77e7-46a1-4eb7-9752-d76608fdd77a
---
Don't post or propose posting comments on PRs on the user's behalf, even when feedback is "answerable" rather than code-actionable.

**Why:** Kevin handles social/communication artifacts on PRs himself. PR comments carry his voice, judgment, and tone — me drafting them and asking him to relay risks misrepresenting his stance, especially with engineering reviewers he knows. He has corrected this twice (once on USVC-591 when I suggested replying to a reviewer's "is there a better way" question; once when I included a "post a PR-comment reply to avlok" item in a triage plan).

**How to apply:** When triaging PR feedback:
- For code-actionable items: implement the fix.
- For questions, design suggestions, or "informational" feedback: validate locally (read the code, check conventions), report findings to Kevin in chat, and let him decide whether/how to respond on the PR.
- Don't include "draft a reply to X" or "post a comment explaining Y" as plan items.
- Reflect this in plan files: skip the comment-drafting item, leave the validation context in chat for Kevin's reference.
