---
name: nova-ci-merge-testing-traps
description: "Traps when building CI that tests a PR's merge result in nova: BUILDKITE_PULL_REQUEST_BASE_BRANCH is the stack parent, agents re-shallow every build, and cache refs for a PR-only image never exist."
metadata:
  node_type: memory
  type: reference
---

Measured 2026-09-25 while building a merge-check CI step. Each of these invalidated a design.

**`BUILDKITE_PULL_REQUEST_BASE_BRANCH` is the PR's *actual* base, not `main`.** 19 of 224 open nova
PRs are Graphite stacks with a non-main base. Merging that base is a **no-op** (the head already
contains it), so a merge-check keyed on it emits a green "tested the merge" signal on a tree
dozens of commits behind main. To test main drift, merge the **default branch** explicitly.

**The runner agents re-shallow on every build.** `BUILDKITE_GIT_FETCH_FLAGS='-v --prune --depth=2'`
(`angellist/infra` `pulumi/atlas/src/buildkite.ts`) means a `--unshallow` does **not** amortise
across builds — the next fetch truncates back to depth 2. Measured: ~2m48s and +123MB of duplicate
pack *per build* for any branch whose fork point is older than the fetch depth. `--depth=200` is
only ~8 days of main (main gains ~18.6 commits/day). Fix that was verified: add
`--filter=blob:none` to the deepening fetch — same merge base, **8.6s instead of ~150s**.

**A PR-only image can never warm its cache.** `build_step_v3`'s `import_cache` reads
`<name>:cache-<target>-main-arm64`. If the step is skipped on main, nothing ever writes that ref,
so every build is cold. `nova-graph`'s p50 is 55s on main and **172s on PR branches** for exactly
this reason — don't quote main's build time as a PR cost estimate.

**`git merge` without `--no-ff`** fast-forwards when HEAD is an ancestor of the base, producing an
image that is *pure base with the PR's content absent*, which then tests green.

Efficacy ceiling: merge-at-build-time closes only the branch-point→last-push window. nova's
dominant term is review latency (median 2.4h push→merge, 39% >4h), so two independent measurements
put the drift actually closed at **23%** and **36%**. Only a merge queue or
`required_status_checks.strict` closes it. See [[nova-k8s-steps-have-no-checkout]] and
[[github-merge-ref-is-frozen-at-head-push]].
