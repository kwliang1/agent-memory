---
name: Broaden review-agent scope when a repeating bug class surfaces
description: For PRs where an external review (e.g., Cursor) catches multiple instances of the same root pattern across commits, switch from per-commit-delta review to full PR-diff (main..HEAD) review to enumerate ALL instances at once
type: feedback
originSessionId: 5373b9a5-1979-4b34-ad89-cd2d64bd29d2
---
When an external review tool (Cursor, etc.) flags multiple instances of the same root-cause bug pattern across successive commits on the same PR (e.g., USVC-860 PR #1102 had four Cursor catches all on the SSN/EIN normalize-collision pattern surfaced in different code paths), broaden the pre-push review-agent scope.

**Why:** The default per-commit-delta review keeps surfacing the same bug class because each round only sees the latest change, not the whole surface area where the pattern could repeat. Switching to full-PR-diff review forces the reviewer to enumerate every instance of the pattern across all files touched — catching multiple instances in one pass instead of one-per-commit iteration. The user pushed back on the iterative pattern explicitly: "do we need to check for all opportunities? this is the 3rd time we've gotten this pattern of feedback."

**How to apply:**
- Trigger: any time you've taken 2+ commit cycles on the same PR addressing the same root-cause class of bug.
- Snapshot the diff as `git diff origin/main HEAD` (or include staged changes) to capture the full PR surface, not just `git diff HEAD~`.
- Tell the reviewer agent explicitly: "audit every instance of [pattern X] across the entire PR diff, including code paths that weren't touched in the latest commit but that share the root pattern." Pass a concrete list of the prior catches so the reviewer knows what shape to look for.
- Run this broader review BEFORE pushing the next fix, so any additional instances surface in the same round rather than via another Cursor pass.
