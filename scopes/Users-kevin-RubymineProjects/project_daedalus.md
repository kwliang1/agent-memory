---
name: project-daedalus
description: "Daedalus (rule-change scorer over session logs) — design state, handoff path, and the measurement traps it found"
metadata:
  node_type: memory
  type: project
  originSessionId: d24b2a5c-2d2d-4c96-8ccb-63bbc204316c
  modified: 2026-10-10T08:20:34.490Z
---

Daedalus is a sibling project to hydra that scores rule changes against session logs. Repo ~/RubymineProjects/daedalus, remote angellist/daedalus (private), Bun + bun:sqlite. Design approved 2026-10-10; steps 1-4 merged to main that night (PRs #4-#7, gate capped at round 10 by Kevin); step 5 GUI next. Graphite doesn't sync this repo: push with git + gh pr create. Handoff: `~/.claude/review-findings/daedalus/design/HANDOFF.md`; latest per-session handoff is the newest HANDOFF-*.md there. Kevin wants a handoff before every next step (gate rounds included) and a status reply after each step. Doc: https://claude.ai/code/artifact/75639d67-efeb-47a3-b493-9f40f2b622db

**Why:** Kevin wants to back-test agent-rule changes on cost, speed and quality, visually.
**How to apply:** start from HANDOFF.md. The loaded rule version is the hash of the jsonl `instructions` attachment, not the git SHA. Reviewer results land as task-notifications, not the Agent tool_result stub. Logs are kept 90 days (set 10/10), with an archive at ~/.daedalus-archive. Nothing leaves the box. Back-test trap: post-9/30 sessions also switched to opus-5-5 and 1h cache TTL, so $/round drops ~6x for reasons other than the handoff; recount at fixed prices ($0.10/round). Related: [[project-session-token-anatomy]].
