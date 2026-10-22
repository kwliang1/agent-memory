---
name: batch-orphan-alerts-pr
description: PR #450 (2026-10-13) batches mass orphan alerts into one operator message; open follow-ups and the review traps it hit
metadata:
  type: project
---

PR #450 (`kevinliang/batch-orphan-alerts`), pushed 2026-10-13 after 8 gate rounds, needs a daemon restart to take effect once merged.

Follow-ups Kevin agreed to defer:
- A bulk recovery action. `recover all` skips orphans: an orphan's tmux is alive, so `isAlive` is true and `findDeadSessions` (`daemon/recovery.ts`) never lists it.
- The "bridge disconnected for Ns" log uses `createdAt`. No disconnect timestamp is tracked for spawned-session bridges.

**Why:** remembered so the next session doesn't re-derive these.
**How to apply:** CI sets `DEFAULT_SESSION_CHANNEL` (see [[gate-checklist]]). Rounds 4-6 were mostly regressions from earlier review fixes: each async-fallback "re-check" added a new state edge. Kevin chose patch over simplify.
