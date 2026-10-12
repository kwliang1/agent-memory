---
name: gt-submit-dry-run-resets-shared-trunk
description: "`gt submit --dry-run` hard-resets the shared trunk checkout during validation despite printing 'No branches will be pushed'; read-only review agents must be barred from gt/git state commands, not just file edits"
metadata:
  type: feedback
---

On 2026-09-28 a review agent I had spawned as read-only ran, from a worktree:

```
gt submit --dry-run --no-interactive
```

Under its own banner *"No branches will be pushed and no PRs will be opened or updated"*, the
validation step printed `main fast-forwarded to 46ae969ac…` and performed a **`reset` in the shared
`/Users/kevin/RubymineProjects/treasury` checkout** — confirmed in that checkout's reflog
(`reset: moving to 46ae969ac`, `ORIG_HEAD` = the old `ae5060b45`).

Nothing was lost because that tree happened to be clean and the move was a fast-forward to
`origin/main`. Had another session had uncommitted work there, `reset` takes it with **no stash
entry**, which is the same failure class as [[feedback_never_checkout_over_uncommitted_work]] —
and the shared checkout is explicitly shared, per [[shared-checkout-worktree-isolation]].

**Two rules out of this.**

1. **`gt submit` fast-forwards trunk during validation whether or not you asked, dry run included.**
   So "I deliberately have not fast-forwarded the shared checkout" is not a state `gt submit` will
   honour. If the shared checkout might hold uncommitted work, check it (`git -C <checkout> status
   --porcelain`) *before* any `gt submit`, dry run or not.
2. **"Read-only" in a review-agent prompt must prohibit side-effecting commands, not just file
   edits.** My prompt said "Read-only: do NOT edit any file", and the agent reasonably read a
   `--dry-run` as safe. Spell it out: no `gt` subcommands at all, no `git` outside
   `show`/`log`/`diff`/`status`/`grep`/`cat-file`/`rev-parse`/`merge-base`, no writes anywhere
   outside `/tmp`. CLAUDE.md already says a mutating agent gets its own worktree — the gap is that
   a *reviewing* agent can mutate a **different** checkout than the one it was pointed at.

Also learned in the same run, relevant when the gate finishes: **non-interactive `gt submit` opens
the PR as a draft** ("Running in non-interactive mode… new PRs will be created in draft mode"). A
draft gets no reviewers and does not read as open for review — pass `--publish` and `-r`, or submit
interactively. Related: [[worktree-add-sets-upstream-to-main]], [[feedback_use_graphite]].
