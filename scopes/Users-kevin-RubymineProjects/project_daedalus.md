---
name: project-daedalus
description: "Daedalus (rule-change scorer over session logs) — design state, handoff path, and the measurement traps it found"
metadata:
  node_type: memory
  type: project
  originSessionId: d24b2a5c-2d2d-4c96-8ccb-63bbc204316c
  modified: 2026-10-10T08:20:34.490Z
---

Daedalus is a sibling project to hydra that scores rule changes against session logs. Repo ~/RubymineProjects/daedalus, remote angellist/daedalus (private), Bun + bun:sqlite. v1 steps 1-6 merged 10-10/11. Design v3 (any change, not just the gate) approved 10-12; V1 changes detection merged 10-12 as #41 (gate capped at round 6). V2 segments merged 10-12 as #42 (shared ledger rebuilt to v8); V3 per-segment metrics merged 10-13 as #50; V4 `daedalus hits` (code-graph hit rate) merged 10-17 as #56, shared ledger rebuilt to v11; leftovers #57-#63; V8 PR-link analysis and V9 in-page editor are scoped (#37, #38) and need design passes. The shared ledger is the main checkout's data/ledger.sqlite (cli default is repo-relative, so run rebuild from a worktree with --db pointing there). Graphite doesn't sync this repo: push with git + gh pr create. Handoff: `~/.claude/review-findings/daedalus/design/HANDOFF.md`; latest per-session handoff is the newest HANDOFF-*.md there. Kevin wants a handoff before every next step (gate rounds included) and a status reply after each step. Doc: https://claude.ai/code/artifact/75639d67-efeb-47a3-b493-9f40f2b622db

**Why:** Kevin wants to back-test agent-rule changes on cost, speed and quality, visually.
**How to apply:** start from the newest HANDOFF-*.md. A first sighting in logs is not a creation (repo files/skills appear when a session first works there). The loaded rule version is the hash of the jsonl `instructions` attachment, not the git SHA. Reviewer results land as task-notifications, not the Agent tool_result stub. Logs are kept 90 days (set 10/10), with an archive at ~/.daedalus-archive. Nothing leaves the box. Back-test trap: post-9/30 sessions also switched to opus-5-5 and 1h cache TTL, so $/round drops ~6x for reasons other than the handoff; recount at fixed prices ($0.10/round). Related: [[project-session-token-anatomy]].
