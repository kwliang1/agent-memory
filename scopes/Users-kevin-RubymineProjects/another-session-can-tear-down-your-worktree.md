---
name: another-session-can-tear-down-your-worktree
description: "A concurrent session ran nova's worktree-teardown on a worktree this session was mid-review in; commit early because only the branch ref survives."
metadata: 
  node_type: memory
  type: reference
  originSessionId: 4aac9744-d372-4848-aee0-403310e70ae1
  modified: 2026-09-18T07:23:03.212Z
---

Mid-way through a review gate, `/Users/kevin/RubymineProjects/nova/.worktrees/bank1936` vanished —
directory, docker containers and its postgres (port 7799) all gone, and the entry gone from
`git worktree list`. Another session ran `just worktree-teardown`. Nothing announced it.

**What survived:** the branch ref in the main repo's object store. Committed work was intact at
`git rev-parse kevinliang/bank-1936`. Uncommitted work would have been unrecoverable — there is no
stash entry, no reflog for a working tree.

**Recovery** (~10 min, and the test DB does not come back):
```sh
cd /Users/kevin/RubymineProjects/nova
git worktree prune
git worktree add .worktrees/<name> <branch>     # re-attach, do NOT use -b, the branch exists
cd .worktrees/<name> && just worktree-init      # no args = re-provision this directory
just turbo build --filter=graph                 # init leaves packages unbuilt
just codegen --filter=graph && just codegen --filter='!graph'   # or app tests die on undefined enums
# recreate + migrate the test DB by hand; init does not
```
A `CREATE DATABASE <name>_test TEMPLATE <name>` inherits a half-applied migration state that
`migrate deploy` then refuses — drop it and create empty instead.

**So:** commit before stepping away from a worktree for any length of time, and tell subagents to
read the branch ref (`git show <branch>:<path>`) rather than a worktree path, so a teardown under
them costs nothing. See [[shared-checkout-worktree-isolation]] and
[[feedback_use_worktree_for_other_branches]].
