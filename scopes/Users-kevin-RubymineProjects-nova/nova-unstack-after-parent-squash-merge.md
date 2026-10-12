---
name: nova-unstack-after-parent-squash-merge
description: "Un-stacking a nova branch after its stack parent squash-merges: the conflict probe needs an explicit --merge-base or it reports bogus conflicts, and gt parent goes EMPTY"
metadata:
  node_type: memory
  type: reference
  originSessionId: 36706420-7e0a-4299-a8e2-70515f3b2b55
  modified: 2026-09-29T18:45:01.813Z
---

When a stack parent's PR squash-merges on nova, the remote branch is **deleted** and the local parent
commit is **not** an ancestor of `origin/main` — the squash is a new commit. `git fetch origin <parent>`
fails with "couldn't find remote ref", but the local `origin/<parent>` ref survives (no `--prune`), so
`git show origin/<parent>:<path>` still works for base comparisons.

**The trap that cost me a wrong report (2026-09-29, BANK-2121 / #10599):** the naive conflict probe
`git merge-tree --write-tree origin/main HEAD` reported **5 conflicts** in the 5 files the parent
touched. They were bogus. `merge-tree` merges from the *true* merge-base (the commit before the
parent), so the parent's content arrives from both sides — main via the squash, and your branch via
its own parent commit. Use cherry-pick semantics instead:

```sh
git merge-tree --write-tree --merge-base=<old-parent-sha> origin/main HEAD   # exit 0, 0 conflicts
```

Full sequence that worked:

```sh
git show <old-parent> --format="" | grep -v '^index '   # confirm byte-identical to the squash commit
git rebase --onto origin/main <old-parent-sha>          # drops the parent, replays your commit
md5 -q <(git diff origin/main...HEAD)                   # must equal the pre-rebase md5
```

That last line is the point: if the reviewed diff is byte-identical before and after, a completed
review round still applies to the rebased branch — verify by checksum, not by argument. Use the
three-dot form; it measures from the merge-base, so it does not drift when `main` moves again.

**`gt parent` returns EMPTY, not an error.** Graphite's tracking diverges ("has diverged from
Graphite's tracking"), and an empty `$(gt parent)` is exactly the CLAUDE.md trap where
`git show ":<path>"` silently reads *staged* content. Use explicit `origin/main` everywhere until you
re-point with `gt track --parent main`. It may report "includes N commits" (308, for me) because
**local `main` is far behind `origin/main`** — harmless for `git push` + `gh pr create`, but do not
`gt submit` off that stale ref.

**Rebase aftercare, all of it required.** Apply pending migrations to **both** the dev and `_test` DBs
(`POSTGRES_URL=..._test npx prisma migrate deploy` from `packages/prisma`; use `deploy`, never
`migrate dev`); `packages/prisma` codegen + build; `capital-api schema:dump` **before** graph's
(see [[nova-codegen-order-capital-api-first]]); `app codegen` verified by **mtime**, not its
`[SUCCESS]` line.

One extra step not covered by the existing stale-codegen notes: `graph tsc` then failed **exit 2** with
`has no exported member '<X>TestDocument'` in files the branch never touched. `schema:dump` does **not**
refresh `graph/test/types/gen/` — `pnpm -C graph test:codegen` does. Do not chase those errors as real.


**A stacked child's green merge status is an artifact of its base, not of its readiness.** On
2026-09-29 (#10608 on #10607) the child read `mergeStateStatus: CLEAN` with `reviewDecision: null` —
zero approvals — purely because its base was the parent *branch*, which carries no ruleset.
`gh api repos/angellist/nova/rules/branches/main` has `required_approving_review_count: 1`, so that
rule only starts applying the moment the parent squash-merges and GitHub retargets the child to
`main`. It flips CLEAN → BLOCKED with nothing in the diff having changed. Check the child's approval
count *before* merging the parent, not after.

Cursor's approval agent will not backfill it either: it posts a review body saying why it declined
(e.g. "I did not approve because Cursor Bugbot reported an unresolved … finding"), and resolving
that Bugbot thread does **not** re-trigger it — only a new push does. A stacked child whose only
blocker was a since-answered bot finding sits at zero approvals indefinitely.
Related: [[graph-tsc-ooms-and-reads-as-clean]], [[tsc-filter-by-cause-not-by-path]],
[[nova-worktree-sync-clones-failed-migration]], [[reference_stacked_pr_peer_forcepush]]
