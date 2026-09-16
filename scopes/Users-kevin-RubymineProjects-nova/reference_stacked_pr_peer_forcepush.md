---
name: reference_stacked_pr_peer_forcepush
description: "Stacking a PR on a peer agent's in-progress branch: they may force-push; rebase --onto before opening the PR"
metadata: 
  node_type: memory
  type: reference
  originSessionId: 42d5578e-1336-4a70-a1fd-7bf465b42836
  modified: 2026-08-20T07:22:23.262Z
---

When stacking a PR on a sibling session's in-progress branch (common in the build-wt multi-agent flow — e.g. 3811 stacked on flint's 3789), the peer may **force-push/rewrite** their branch after you based on it. If you then open a PR with `--base <peer-branch>`, the GitHub diff uses the merge-base, and a rewritten peer branch drops the merge-base back to `main`, so the PR shows a messy diff (your changes + reverting the peer's new work + re-adding their old work).

Before opening the PR:
1. `git fetch origin <peer-branch>` then `git merge-base --is-ancestor <your-base-sha> <peer-tip>` — exit 0 = clean add-on-top; non-zero = they rewrote.
2. If rewritten, `git rebase --onto <peer-new-tip> <your-old-base-sha>` to re-parent your commit(s). Check `comm -12` of their-changed-files vs your-changed-files first — no overlap ⇒ conflict-free rebase.
3. Re-verify your imports against their new exports (they may have changed the very types you depend on), then re-run typecheck + affected specs.
4. `git push --force-with-lease`, then `gh pr create --base <peer-branch>` so the diff shows only your changes. GitHub retargets to `main` automatically once the peer branch merges.

See [[reference_bare_worktree_bringup]] (stale local main → `gh pr create`, not `gt submit`).
