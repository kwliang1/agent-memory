---
name: feedback-no-peer-progress-relays
description: "Don't relay another session's progress to Kevin; only act when the peer's update requires action from this session"
metadata:
  node_type: memory
  type: feedback
  originSessionId: 1cde6402-c916-4783-8bd1-52dc47d7ed52
  modified: 2026-11-04T21:33:04.637Z
---

Don't forward a peer session's status updates (e.g. "ember committed X, gate round 9 running") to Kevin. When a peer pings, act silently on whatever it hands me (restack, rebase) and report only my own outcome if it matters.

**Why:** Kevin, 2026-11-04: "you don't need to apprise me of ember's progress. just restack when it tells you its done."

**How to apply:** On a cross-session message, ask "does this need me to do something?" If no, no reply to Kevin. If yes, do it; tell Kevin only on a failure or a decision he must make. Relates to [[status-update-each-step]], which covers *my own* long runs, not peers'.
