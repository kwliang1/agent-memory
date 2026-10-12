---
name: worktree-add-sets-upstream-to-main
description: "`git worktree add -b <branch> <path> origin/main` sets the new branch's upstream to main, so git's own push error tells you to run `git push origin HEAD:main`"
metadata:
  type: reference
---

Creating a worktree with `git worktree add -b kevinliang/foo <path> origin/main` records
`branch.kevinliang/foo.merge = refs/heads/main`. The branch name and the upstream name then differ,
so a bare `git push` refuses — and the **first remedy git prints** is:

```
fatal: The upstream branch of your current branch does not match
the name of your current branch.  To push to the upstream branch
on the remote, use

    git push origin HEAD:main
```

Copy that suggestion and the commit goes straight onto `main`, against the never-commit-to-main
rule, from a branch that looks correctly named the whole time. Found by a review agent on
2026-09-28 on `kevinliang/ach-push-created-maps-to-queued`; nothing else in six prior review rounds
noticed it, because the branch name, the commit and the base were all correct.

**How to apply:** right after `git worktree add -b … origin/main`, run `git branch --unset-upstream`
in the new worktree. The bare-push error then suggests
`git push --set-upstream origin <branch>`, which is right. Check with
`git config --get branch.<branch>.merge` — it should be empty, not `refs/heads/main`. `gt submit`
sets the ref correctly on its own and sidesteps this, so the hazard only bites when reaching for
raw git; that is exactly when the error text is most likely to be trusted.

Unrelated to, but discovered alongside, [[treasury-worktree-spec-env-quotes-and-rustfs]]. See also
[[feedback_use_graphite]] — using `gt` avoids this, and this note is the reason the raw-git fallback
needs care. `gt track --parent main` is still needed separately for a hand-made worktree branch, or
`gt parent` errors and `gt submit` prompts interactively.
