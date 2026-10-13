---
name: gt-submit-stale-trunk-wrong-pr-title
description: "gt submit --ignore-out-of-sync-trunk from a worktree whose local main is stale creates the PR with an UNRELATED commit's title — always re-check and PATCH title/body"
metadata:
  node_type: memory
  type: reference
  originSessionId: 95f75b8e-ed81-41ca-bc86-5922bea06aa4
  modified: 2026-09-30T01:17:13.210Z
---

When the shared checkout's local `main` is stale (and can't be fast-forwarded because another
session has WIP staged on it), `gt submit` aborts with "trunk branch is out of date and could not be
updated". `--ignore-out-of-sync-trunk` gets past it and pushes the right commits — but the PR it
creates can carry an **unrelated commit's title and body**. Seen 2026-09-29 on nova#10614: head sha,
1 commit and 11 files were correct, title was `fix: clear resolved draft contact email warnings (#10146)`.

Graphite prints its own warning ("Failure to update could result in incorrect metadata being used to
submit PRs") and then does exactly that.

**How to apply:** after any `--ignore-out-of-sync-trunk` submit, fetch the PR (`gh api
repos/{owner}/{repo}/pulls/<N> --jq '{title,commits,head:.head.sha}'`) and PATCH title + body before
telling anyone it's up. Also pass `--publish`: non-interactive submit creates drafts by default.
Don't "fix" the stale trunk by touching the shared checkout ([[shared-checkout-worktree-isolation]]).
