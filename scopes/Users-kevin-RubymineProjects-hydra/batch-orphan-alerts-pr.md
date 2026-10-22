---
name: batch-orphan-alerts-pr
description: Mass orphan alerts are batched into one operator message; the follow-ups deferred and the review trap it hit
metadata:
  type: project
---

Mass orphan alerts are batched into one operator message. It needs a daemon restart to take effect. Follow-ups Kevin agreed to defer:
- A bulk recovery action. `recover all` skips orphans: an orphan's tmux is alive, so `isAlive` is true and `findDeadSessions` (`daemon/recovery.ts`) never lists it.
- The "bridge disconnected for Ns" log uses `createdAt`. No disconnect timestamp is tracked for spawned-session bridges.

**Why:** so the next session doesn't re-derive these.

**How to apply:** CI sets `DEFAULT_SESSION_CHANNEL` (see [[gate-checklist]]). Most of that gate's resets were regressions from earlier review fixes: each async-fallback "re-check" added a new state edge. Kevin chose patch over simplify.
