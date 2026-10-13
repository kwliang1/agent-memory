---
name: hydra-worktree-add-15s-timeout
description: "spawn_session's worktree param dies on a cold nova checkout (15s timeout) and leaves an orphaned dir + dangling wt/ branch behind"
metadata: 
  node_type: memory
  type: project
  originSessionId: e77114cd-e9b9-45d6-9256-adc01111925c
  modified: 2026-09-25T22:42:08.358Z
---

`hydra/daemon/worktree-manager.ts:105` runs `git worktree add -b <branch> <dir> <base>` with a hard **15 second timeout**. Measured checkout times:

| repo | files | time | verdict |
|---|---|---|---|
| nova | 9,530 | ~6.6s warm | borderline — fails cold or under IO contention (seen twice on 2026-09-21, dying at 42% then 82%) |
| **venture** | **29,996** | **68s** | **always fails — 15s is unreachable, `spawn-wt: venture ...` can never succeed** |

So for venture this is not flakiness, it's a hard block. Confirmed 2026-09-25 when `spawn-wt: venture rca <sentry>` failed and Kevin got **no error message at all** — the spawn just silently never happened, and he had to ask twice why nothing was running.

**The damage:** that failure path does no cleanup. Each failed attempt leaves behind
- a partially-checked-out directory (~97MB / thousands of files) with **no `.git` link**, and
- a dangling `wt/<name>` branch pointing at the base commit.

The leftover branch then blocks a later spawn that draws the same name from the pool.

**This is the failure you will actually observe, and it is NOT the timeout.** The timeout fires once; the leftover branch then poisons that name permanently. Every later spawn drawing it dies instantly with:

```
fatal: a branch named 'wt/<name>' already exists
```

By 2026-09-25 four nova names were poisoned (`wt/atlas`, `wt/comet`, `wt/patch`, `wt/qubit`), so Kevin hit "spawn failed" twice in one day on unrelated requests. **Read the actual git error before diagnosing** — I assumed the timeout (correct for the venture case that morning) and told him the wrong cause for this one.

Detect and clear:
```sh
# dangling = NO leading '+'. A '+' means it IS checked out in a live worktree — leave those alone.
git -C <repo> branch --list 'wt/*'
# prove a candidate holds nothing before deleting (both must be empty/0):
git rev-list --count origin/main..wt/<n>
files=$(git diff --name-only origin/main...wt/<n>); git diff origin/main wt/<n> -- $files
git branch -D wt/<n>
```
A dangling `wt/*` branch is normally empty (0 commits, 0 content diff) because the checkout died before any work — but check, don't assume.

**How to apply:**
1. Don't just retry — a cold repo will fail again the same way.
2. Create the worktree yourself, outside the timeout, then spawn **without** the `worktree` param and put the path in the topic ("first command: cd <path>; do not create a worktree").
3. Clean up after a failure: `rm -rf` the orphan dir, `git branch -D wt/<name>`, `git worktree prune`.
4. **Before deleting any orphan, verify nothing owns it** — check for a `.git` link, `git worktree list`, and whether any process has it as cwd. A concurrently-spawned session can grab the same name; see [[another-session-can-tear-down-your-worktree]] and [[feedback_use_worktree_for_other_branches]].

Also note `git worktree prune` only removes *admin entries* for missing worktrees — it never deletes files, so it's safe to run while diagnosing.

**Repo setup differs — check before hand-rolling.** nova needs its `worktree-dev` skill / `just worktree-init` (ports, infra, `.worktree-context.md`, `BASE_URL`); a bare `git worktree add` there yields a worktree no Playwright task can use — see [[nova-use-worktree-dev-skill]]. **venture has no such tooling**: a plain `git worktree add` is correct, plus `direnv allow` once (AGENTS.md:93) and `direnv exec .` prefixes thereafter. Also never `rake db:migrate` from a venture worktree — the local DB is shared across all of them (AGENTS.md:154).
