---
name: bridge-exit-records-pr
description: Bridge-life exit records: where to look after a bridge death; 16 tests fail locally on main
metadata:
  type: project
---

Each bridge writes `<state dir>/bridge-life/<sid>-<pid>.jsonl`, and the daemon logs `bridge exit check for session …`. After the next mass bridge death, grep the daemon log for that phrase before anything else.

**Why:** one laptop wake killed 19 bridges and left no trace (see [[disconnected-live-sessions-bridge-death]]).

**How to apply:**
- The records exist only after a daemon restart, and only for bridges started after that.
- 16 tests in main-handoff, main-session and session-health fail locally on untouched origin/main while CI is green. Don't chase them as your own regression.
- `gt create` fails on the untracked `wt/<name>` branch. Use `git checkout -b` + `gt track --parent main`.
