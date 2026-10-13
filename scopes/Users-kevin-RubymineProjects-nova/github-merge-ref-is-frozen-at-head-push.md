---
name: github-merge-ref-is-frozen-at-head-push
description: "refs/pull/N/merge is NOT a live merge with main — GitHub freezes it at the last head push and keeps it after a PR goes conflicting; verified on angellist/nova 2026-09-18."
metadata:
  node_type: memory
  type: reference
---

Two properties of GitHub's test-merge ref that break the obvious "just build the merge result" CI design:

**1. The base parent is frozen at the last head push, not main's tip.** Sampled 4 open nova PRs
against main tip `e64781206f9a`; the merge ref's `parents[0]` tracked each PR's head push time and
matched the tip in 0 of 4 (a reviewer got 0 of 12):

| PR | mergeref base | head pushed |
|---|---|---|
| 10321 | `3899fcfa6079` | 20:26:18Z |
| 10313 | `c1c922345999` | 18:15:04Z |
| 10291 | `4006f9a2fc55` | 16:00:30Z |

So consuming the ref tests *main as of your last push*, never *main as of now*. It can protect the
push moment, not the merge moment.

**2. It survives the PR going conflicting.** All 8 `CONFLICTING` open nova PRs still had a merge
ref, head parent still matching. PR #6706 resolved to a **March** tree (6,790 files vs today's
9,710) whose head parent matched exactly. So "a conflicting PR has no merge ref" is false, and a
guard that checks only the head parent passes on a months-stale tree.

Parent order *is* reliable: `parents[0]` = base, `parents[1]` = head (verified on 5 PRs incl. a
draft and a stacked PR). `git fetch --no-tags --depth=1 origin <raw-sha>` works against GitHub even
for unreachable commits, and depth-1 into a `--depth=2` clone yields a complete tree.

Corollary: to test a merge result in CI, **do the merge yourself against the live base tip** in one
job. Don't consume the ref. See [[nova-k8s-steps-have-no-checkout]].
