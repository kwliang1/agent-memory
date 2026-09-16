---
name: wip-stale-worktree-names-pr
description: "In-flight hydra PR (as of 2026-09-02) — pickSessionName skips stale/foreign .worktrees dirs; branch, state, remaining review items"
metadata: 
  node_type: memory
  type: project
  originSessionId: 31f84159-df01-49f9-9d70-c8d7e1c4e2d8
  modified: 2026-09-03T00:58:34.766Z
---

Branch `kevinliang/hydra-skip-stale-worktree-session-names` (hydra, commit 7c8494f, gt-tracked on main), unpushed as of 2026-09-02. PR body draft: `~/.claude-byte/hydra-lark-pr-body.md`. Checkpoint with remaining round-5 review items posted in Slack thread D0BE3RB4Y00:1788389791.148499.

**Why:** session `lark` was reaped mid review-gate (5 rounds done, 0 consecutive clean). Deploy is blocked until 2 clean rounds + push.

**How to apply:** resume from the branch, apply the checkpoint's items 1–4 (locked worktrees always conflict; stdio pipe stderr; exhaustion log wording; description corrections), rerun review rounds, push to `origin` (sf8193/hydra). Run tests with `HYDRA_STATE_DIR=$(mktemp -d) bun test` — bare `bun test` rewrites live daemon state.
