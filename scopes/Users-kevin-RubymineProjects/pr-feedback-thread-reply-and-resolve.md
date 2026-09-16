---
name: pr-feedback-thread-reply-and-resolve
description: "Fixed a BOT review thread via a code change? Reply in it AND resolve it. Human threads: draft only — the BLOCKING gate in CLAUDE.md wins."
metadata: 
  node_type: memory
  type: feedback
  originSessionId: 2cc959b9-7b6d-4c0f-bc9c-486641c0ae8d
  modified: 2026-08-23T22:22:22.674Z
---

**Scope correction (2026-09-15): this applies to BOT threads. For human threads it does not.** Kevin's CLAUDE.md carries a BLOCKING rule — "never post a reply to a human reviewer's PR comment without my explicit approval, in any form — agreeing, pushing back, or saying 'done'." Taken together: resolve freely, reply freely to bots, and for a human thread draft the reply and wait. Do not run step 1 below against a human comment. His words are preserved verbatim; only the scope is narrowed.

Kevin (2026-08-23): "if a thread is resolved by you via a code change, always reply to the feedback thread and mark it as resolved."

**Why:** a silent code fix leaves the reviewer/bot thread open and the resolution undocumented — the reviewer can't see it was addressed or why.

**How to apply:** after pushing a change that addresses a PR review comment (Cursor Bugbot, a human, etc.):
1. Reply in that thread explaining the fix — `gh api repos/{owner}/{repo}/pulls/{pr}/comments/{comment_id}/replies -f body="..."` (comment_id = the number in `#discussion_r<id>`).
2. Resolve the thread (GraphQL; REST can't): query `repository.pullRequest.reviewThreads` for the node `id` whose `comments.nodes[0].databaseId == comment_id`, then `mutation{ resolveReviewThread(input:{threadId:$id}){ thread{ isResolved } } }`.

Done for the Bugbot staging-Slack finding on treasury #8641 (see [[bank-1858-flowdash-divergence-monitor]]).
