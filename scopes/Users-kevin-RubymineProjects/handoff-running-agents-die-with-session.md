---
name: handoff-running-agents-die-with-session
description: "A handoff that says \"reviewers were launched, wait for their files\" is stale on arrival; the agents died with the old session, so relaunch instead of waiting"
metadata:
  node_type: memory
  type: feedback
  originSessionId: 1dcbef9d-5763-4dbe-a21a-717787903c85
  modified: 2026-10-16T01:00:34.388Z
---

A handoff's Next action read "wait for all three round-5 verdict files to exist; agents were launched ~17:17 and take ~6 min". They never appeared: subagents belong to the session that spawned them and die with it on handoff (2026-10-15).

**Why:** waiting on a file that nothing will write stalls the gate silently, and the old session's chat returns are gone too.

**How to apply:** on arrival, `ls` the findings dir once; if the promised files are missing, relaunch that round from the saved briefs (the `brief<N>_<lens>.md` files in the old scratchpad are the full per-lens prompts and can be handed to fresh agents as-is). When writing a handoff mid-round, say "relaunch round N from these briefs", not "wait for the files". See [[review-gate-playbook]].
