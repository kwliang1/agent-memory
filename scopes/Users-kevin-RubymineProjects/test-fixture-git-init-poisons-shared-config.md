---
name: test-fixture-git-init-poisons-shared-config
description: "A test helper that runs `git init .` + `git config user.*` can reinitialise the checkout it is running from — and in a linked worktree that write lands in the SHARED config, hitting every worktree"
metadata:
  node_type: memory
  type: feedback
  originSessionId: 85319a80-b18c-4af4-861c-0876f903e673
  modified: 2026-09-29T23:14:05.415Z
---

A fixture helper shaped like this is a loaded gun:

```zsh
gitinit() {
  git init -q "$@" . && git config user.email t@t && git config user.name t
}
...
( cd "$fixturedir"; gitinit; ... )
```

If that `cd` ever fails, cwd is still the checkout running the suite. `git init .` then
**reinitialises that repo** and the `git config` writes rewrite its identity.

**Two things make it much worse than it sounds.**

1. `git config --local` in a **linked worktree** writes to `$GIT_COMMON_DIR/config`, not to the
   per-worktree config — so the damage is shared by every worktree of that repo, including the
   main checkout.
2. `git init .` run from a linked worktree writes `core.worktree = <that worktree>` into the same
   shared config. After that, `git -C <main checkout> rev-parse --show-toplevel` answers with the
   **linked worktree's** path. Every git command aimed at the main checkout silently operates on
   the other tree.

**This bit on 2026-09-29** in `agent-memory` (`test/ts-indexer-test.sh`). `~/agent-memory/.git/config`
gained `core.worktree = /Users/kevin/agent-memory-step5` and a `[user] t <t@t>` block, so the
production checkout had been answering as the step-6 worktree for four hours — see
[[agent-memory-worktree-is-production]] for why that repo in particular is dangerous to redirect.

**The symptom you will actually notice:** commits get `committer t <t@t>` while the author stays
correct, because `--amend` preserves the author. GitHub then shows the commit **Unverified** even
though it is signed with the right key, and branch protection blocks the merge. `%G?` will not tell
you — see [[feedback_signed-commit-verify-raw-object]]. Check `git log --format='%cn <%ce>'`.

**How to apply.**

Diagnose:
```sh
git config --local --show-origin --get-regexp '^(user\.|core\.worktree)'
git -C <main checkout> rev-parse --show-toplevel   # must be the main checkout
git log -5 --format='%h %cn <%ce> | %an'
```
Repair is `git config --local --unset core.worktree` and the two `user.*` keys. Back the config up
first; a repo that legitimately sets `core.worktree` exists, so look before you unset.

Prevent: make the helper refuse to run anywhere that is already a repo, rather than trusting the
`cd`.
```zsh
if git rev-parse --git-dir >/dev/null 2>&1; then
  print -u2 "gitinit: refusing to init inside an existing repo: $PWD"; exit 1
fi
```
`GIT_CONFIG_GLOBAL=/dev/null` does **not** protect you here — it redirects global config, while
`git config` with no scope flag writes local.

Related: [[feedback_verify_new_assertions_can_fail]], [[shared-checkout-worktree-isolation]].
