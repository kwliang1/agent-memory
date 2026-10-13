---
name: feedback_review_round_can_die_on_auth
description: A review-gate round can report as launched and then every reviewer dies on auth — verify each returned a real verdict before counting the round
metadata:
  node_type: memory
  type: feedback
  originSessionId: e668db28-4c5f-4e4d-897c-5c38e4a151af
  modified: 2026-09-28T16:22:22.542Z
---

A review round is not complete because it was spawned. On 2026-09-28 all three round-5 reviewers on `kevinliang/usage-phase-attribution` died ~6 minutes after launch with their entire final message being `Not logged in · Please run /login`. The parent session had already told Kevin "round 5 going out now", then went silent on the same auth expiry. Two hours later the round looked launched and had produced **nothing**.

**Why:** the Claude Code credential can expire mid-session. A subagent that hits it does not error out — it terminates with the login string as its assistant text, which reads like a normal (short) completion to anything not looking closely.

**How to apply:** before crediting a round toward the 2-clean-rounds gate, confirm each reviewer returned an actual verdict. Cheapest check is the last assistant text of each agent transcript:

```sh
cd ~/.claude/projects/<proj>/<session-id>/subagents
jq -r 'select(.type=="assistant") | .message.content
       | if type=="array" then (map(select(.type=="text").text)|join(" ")) else "" end' agent-<id>.jsonl \
  | grep -v '^$' | tail -1
```

`Not logged in`, or a verdict far shorter than the lens asked for, means the round did not happen — re-run it from scratch. Do not count it as clean and do not count it as feedback; it is a void round either way.

Note `python3` is not usable for this from a subagents dir — asdf has no version set there and the shim exits 126. Use `jq`.

**Other death strings, 30 days to 2026-10-08:** 48 reviewers died: 25 hit the spend limit
(`You've hit your individual spend limit`), 20 got `API Error: Can't reach the API server (ENOTFOUND)`,
3 were not logged in. All are void rounds. Separately, reviewers wedged for hours (110,930s and
492,010s) waiting on a background `find`. Give each reviewer about 20 minutes, then void and relaunch
that lens rather than waiting on the notification.

Related: [[feedback_review_gate_count]], [[feedback_freeze_tree_during_review_rounds]], [[feedback_verify_reviewer_negative_results]].
