---
name: bridge-exit-records-pr
description: PR #451 (2026-10-13) bridge-life exit records; where to look after a bridge death; 16 tests fail locally on main
metadata:
  type: project
---

PR #451 (MERGED 2026-10-13 as 97ddbe3): each bridge writes `<state dir>/bridge-life/<sid>-<pid>.jsonl`, and the daemon logs `bridge exit check for session …`. After the next mass bridge death, grep the daemon log for that phrase before anything else. The review findings and outcomes from 4 gate rounds are in `~/.claude/review-findings/hydra/kevinliang-bridge-exit-records/`.

**Why:** the 2026-10-13 wake killed 19 bridges and left no trace (see [[disconnected-live-sessions-bridge-death]]).

**How to apply:**
- The PR only helps after a daemon restart, and only for bridges started after the deploy.
- 16 tests in main-handoff, main-session and session-health fail locally on untouched origin/main (CI green). Don't chase them as your own regression.
- `gt create` fails on the untracked `wt/<name>` branch. Use `git checkout -b` + `gt track --parent main`.
