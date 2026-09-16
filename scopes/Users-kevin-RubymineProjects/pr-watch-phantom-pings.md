---
name: pr-watch-phantom-pings
description: "The pr-watch bridge bot fires empty \"[PR Feedback] — N new item(s)\" pings with no corresponding GitHub activity; always verify via gh api before reacting or relaying."
metadata: 
  node_type: memory
  type: reference
  originSessionId: 19d9b6d6-1e01-45fd-808b-4f0c2036f1d6
---

Observed twice on treasury PR #8211 (2026-07-14 04:16 UTC and 2026-07-15 09:07 UTC): pr-watch posted "[PR Feedback] — 1 new item(s)" with an empty body, and GitHub showed zero new comments (issue or inline), reviews, or timeline events in the window.

**How to apply:** on any pr-watch ping, verify before replying — `gh api repos/{owner}/{repo}/issues/{n}/comments?since=...`, `pulls/{n}/comments?since=...`, `pulls/{n}/reviews`, and the issue timeline. If all empty, tell Kevin it's watcher noise in one line; don't re-triage.
