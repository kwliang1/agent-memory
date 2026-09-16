---
name: feedback-resolve-ai-review-threads
description: "When addressing AI review feedback (Cursor Bugbot etc.), always reply on the thread AND resolve it. Also: Kevin's bar for code comments is much tighter than I default to."
metadata: 
  node_type: memory
  type: feedback
  originSessionId: 1a88ecdb-da63-4f54-b22e-a372bec5eacc
  modified: 2026-07-31T22:23:22.437Z
---

## Comment and resolve, every time

Kevin, 2026-07-31: "when you address AI feedback going forward, I want you to comment and resolve the thread."

So for every Cursor Bugbot / AI reviewer finding: reply on the thread saying what changed (or why it's a false positive / stale), then resolve it. Don't leave an open "High Severity" thread on a PR a human is about to review, and don't silently fix something without recording why on the thread.

**Why:** an unaddressed bot comment reads as an unfixed bug to the next reviewer. A stale one (bot reviewed an older commit) reads the same way unless you say so.

**How:**
```bash
# list threads + ids + resolution state
gh api graphql -f query='{repository(owner:"angellist",name:"treasury"){pullRequest(number:N){reviewThreads(first:20){nodes{id isResolved comments(first:1){nodes{path body}}}}}}}'
# reply
gh api graphql -f query='mutation($t:ID!,$b:String!){addPullRequestReviewThreadReply(input:{pullRequestReviewThreadId:$t,body:$b}){comment{url}}}' -f t=PRRT_... -f b='...'
# resolve
gh api graphql -f query='mutation($t:ID!){resolveReviewThread(input:{threadId:$t}){thread{isResolved}}}' -f t=PRRT_...
```
Threads whose lines change can auto-resolve, but still reply so the record explains it. Note the reply posts as **kwliang1**, so pr-watch will echo it back as new "feedback" — that's your own comment, not a new finding.

## Code comments: much shorter than I default to

Same day, on a 6-line comment: "this comment and all others in this PR should be more concise. or deleted all together." Trimming BANK-1595 took 60 added comment lines down to 29.

Treasury CLAUDE.md already says this ("Default to one short line; multi-line/paragraph comments are a smell — cut them hard") and I under-applied it. The working bar:
- One line. Two only if the second earns it.
- Delete anything restating the code, and any narrative recap of the failure mode. That belongs in the PR body or commit message.
- Keep only the non-obvious WHY, and a ticket ref when a comment prevents someone re-breaking it (e.g. TREASURY-66T).

Same instinct as [[feedback-plain-english-no-ai-prose]] applied to code rather than chat.
