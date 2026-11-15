---
name: memory-paths-are-symlinked
description: Matching ledger paths to edits — ~/.claude/projects/*/memory symlinks into ~/agent-memory/scopes, so compare resolved paths and bound the time window
metadata:
  type: feedback
---

`~/.claude/projects/-<scope>/memory` is a symlink to `~/agent-memory/scopes/<scope>`. Logs record memory loads under the `.claude/projects` path, while agents often write through the `agent-memory/scopes` path. An exact-string join between `changes.target` and `touches.path` therefore misses most agent edits. Resolve the directory with realpath on both sides (`canonicalPaths` in src/metrics.ts) before matching.

Also bound any "who caused this change" join in time. A query that matched an edit to the same path at *any* earlier time reported 27 of 33 memory changes as agent-written. With a 24h window and resolved paths the real count was 7 of 27.

**Why:** both mistakes went to Kevin as findings (2026-11-02) and had to be retracted.
**How to apply:** before stating any attribution number from the ledger, check the path forms on both sides of the join, apply a time window, and spot-check three rows by hand. Related: [[stale-shared-checkouts-are-the-norm]].
