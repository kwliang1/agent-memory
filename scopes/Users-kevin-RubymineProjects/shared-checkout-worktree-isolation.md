---
name: shared-checkout-worktree-isolation
description: "The main repo checkouts (e.g. treasury) are shared across concurrent live sessions — commit in an isolated git worktree, not the shared tree"
metadata: 
  node_type: memory
  type: feedback
  originSessionId: 020ffe9e-c44f-4f59-89dc-f4ad9dacf56c
---

The RubymineProjects repo checkouts (confirmed for `treasury` on 2026-07-09) are shared by multiple concurrent spawned sessions. Another session was actively checking out branches / cherry-picking / resetting in the same working tree while I worked.

**What went wrong:** committing in the shared checkout landed my commit stacked on top of *another* session's branch (HEAD had been switched out from under me), left my branch reset to an unrelated commit, and my commit dangling. Nothing was lost (recovered via reflog) but it was a mess.

**Why:** a git working tree has ONE HEAD; concurrent sessions fighting over it clobber each other's branch/checkout state. Object store + refs are shared, so a dangling commit survives, but branch pointers and the working tree do not.

**How to apply:** when committing/pushing in a shared checkout, work in an isolated `git worktree add -b <branch> <path> <base>` off `origin/main` from the start. It shares the object store (so it's cheap) but has its own HEAD and working tree, immune to the other session's churn.

**Worktree gotchas (treasury, plain `git worktree`, not `make setup-worktree`):**
- Husky hooks are broken in a bare worktree: `.husky/pre-commit`/`pre-push` fail with `.husky/_/husky.sh: No such file` → commit/push abort. Use `--no-verify` (validate specs/sorbet yourself first; CI still runs real checks).
- SSH commit signing did NOT attach a signature when relying on repo config; had to force it explicitly: `git -c gpg.format=ssh -c user.signingkey="ssh-ed25519 …" -c gpg.ssh.program="/Applications/1Password.app/Contents/MacOS/op-ssh-sign" commit -S`. Verify the `gpgsig` block is in `git cat-file -p HEAD`; GitHub then shows `verification.verified=true`. Never disable signing (branch protection needs it).

Related: [[build-wt-worktree-targets]], [[onepassword-cli-prompts]].
