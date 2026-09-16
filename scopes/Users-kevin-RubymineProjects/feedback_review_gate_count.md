---
name: Pre-push review gate uses 2 successive clean rounds, not 3
description: For the kevinliang/usvc-673 stack (and similarly framed work), the pre-push review-agent loop bar is 2 successive clean rounds, not 3. Don't escalate past 2.
type: feedback
originSessionId: ceb48a67-d4b7-47ac-bbed-9e209cf22b36
---
For PR-stack work like USVC-673 (and likely other Graphite stacks the user
ships), the pre-push review-agent loop is **2 successive clean rounds**,
not 3. Stop after the second `No concerns.` — don't run a third round
"to be safe."

**Why:** the user explicitly asked to reduce the gate from 3→2 mid-stack.
Running extra rounds wastes time and tokens; the user's stated bar is the
authoritative one. CLAUDE.md's pre-push gate language is "2 successive
rounds with no addressable feedback" — I'd been treating that as a
floor and adding rounds defensively. Don't.

**How to apply:** when running the pre-push review loop, stop the
*moment* you have two consecutive `No concerns.` returns. Don't run a
"final gate" round on top of that. Save the spent rounds for actually-
addressable feedback iterations.
