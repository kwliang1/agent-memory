---
name: hydra-rebase-followups
description: "Open TODOs after rebasing kevinliang/no-spawn-notify-main onto main (2026-07-01): dedup slack self-heal, decide .tool-versions, review resurrect persona, not pushed"
metadata: 
  node_type: memory
  type: project
  originSessionId: b8de99f2-fc23-43eb-9091-530404697b77
---

Branch `kevinliang/no-spawn-notify-main` was rebased onto latest `origin/main` on 2026-07-01 — now 3 commits ahead / 0 behind, **not pushed** (PR #40 is CLOSED). Commit order: spawn-notify removal → persona + OAuth-token-file injection → slack socket-liveness self-heal. Daemon was restarted & verified afterward (all sessions re-attached, `restored N session(s), pruned 0`). Open decisions left when the user said "good for now":

- **Dedup the slack self-heal.** The `fix(slack): self-heal gateway on socket liveness…` commit (adds `attachTransportHeartbeat` in `slack-gateway.ts`) **duplicates** the unmerged `origin/kevinliang/slack-gateway-idle-reconnect` branch (same "gate self-heal on socket liveness, not event recency" fix). Land ONE, drop the other before pushing either.
- **`.tool-versions`** (`bun 1.3.13`) is still untracked — `origin/main` has none. Decide: commit it or leave it.
- **Resurrect persona extension.** The persona-preserving prompt reword was also applied to `buildResurrectPrompt` in `daemon/prompts/session.ts` (a 4th builder), beyond the original WIP scope of 3 (spawn/fork/handoff). Review — keep or revert.
- **If pushing:** run the pre-push review gate first (see global CLAUDE.md); commit SHAs will change on any further rebase, so identify commits by message, not hash.

**Why:** prevents shipping the same slack fix twice and records that the branch is rebased-but-unpushed, so a future session doesn't re-derive the state or lose the dedup decision.
**How to apply:** in the hydra repo on this branch, `git log origin/main..HEAD` for the three commits; `git range-diff` or eyeball the self-heal commit against `origin/kevinliang/slack-gateway-idle-reconnect` and keep the better one.

Related: [[hydra-session-resurrection]] (daemon-restart re-attach behavior), [[hydra-slack-setup]] (bot auth; note the running Slack app's display name is "Russell" but its bot handle in `auth.test`/logs is "senna" — same app, not a separate deprecated one).
