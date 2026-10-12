---
name: bridge-pr-links-auto-watch
description: Posting GitHub PR links in a bridge reply auto-registers PR watches for your session, spamming Kevin's DM
metadata:
  type: feedback
---

Putting GitHub PR URLs in a `reply` on the Slack bridge causes the daemon to **auto-watch every one of them** for your session. Observed 2026-09-18: a Linear status-update draft linking 9 merged nova PRs produced 9 `_Auto-watching_` notices in Kevin's DM within a minute. PRs already watched by another session were skipped, so the set registered is "links in your message, minus ones someone else holds."

Registration lags the post — `list_watches` right after showed only 1 of the 9; all 9 appeared ~2 min later.

**Why:** Kevin's reaction was "none of these need to be watched from this session." Watches on already-merged PRs are pure noise, and [[pr-watch-phantom-pings]] means that noise is also unreliable.

**How to apply:** any time a reply contains PR links — status updates, review summaries, stack rundowns — follow up with `list_watches(all: true)` a minute later and `unwatch_pr` everything owned by your session. Never unwatch another session's: those are live review loops. Related: [[always-reply-via-tool]], [[main-session-spawn-notifications]].
