---
name: negative-check-toggles-use-edit
description: "When temporarily reverting one fix to prove a test is load-bearing, toggle it with the Edit tool (unique old_string), never sed — a shared pattern silently clobbers other call sites."
metadata: 
  node_type: memory
  type: feedback
  originSessionId: 9bc97e97-764e-47f9-ac44-d3459c01a56c
  modified: 2026-09-02T22:45:43.923Z
---

Proving a fix is load-bearing (revert it, watch the test fail, restore) is worth doing — but do the toggle with `Edit` on a unique `old_string`, never `sed -i` on a short pattern.

**Why:** On BANK-1943 (2026-09-02) the restore `sed 's|idempotencyKey: resolveKey(args) }|...|'` matched a *second* site (`handleAlreadyCommitted`'s `findCommitIdempotency` lookup) and rewrote it to look up a random uuid, so three unrelated conflict-detection tests started reading `ALREADY_COMMITTED`. It cost a DB forensics round before `git diff` showed it.

**How to apply:** after any toggle round-trip, `git diff` the file and confirm the only hunks are the intended ones before trusting a test result. If a bulk toggle is unavoidable, `grep -c` the pattern first and expect exactly 1. See [[spawned-nova-worktree-is-bare]] for the rest of the spawned-session test workflow.
