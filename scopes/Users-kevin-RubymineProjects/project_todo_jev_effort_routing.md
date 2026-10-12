---
name: project-todo-jev-effort-routing
description: "PARKED TODO (2026-09-29) — use TypeSafe's Jev classifier in hydra to ratchet a session's effort per inbound prompt via Claude Code's /effort command"
metadata:
  node_type: memory
  type: project
  originSessionId: 4adcf8aa-2579-40b2-88cd-afb331a01c09
  modified: 2026-09-29T23:31:07.613Z
---

Kevin parked this on 2026-09-29: have hydra classify each inbound Slack prompt with Jev (typesafe.ai/blog/introducing-system-one-models-and-jev — typed decisions, 70–500ms, $0.042/MTok in) into an effort level, then send `/effort <level>` to the tmux pane before delivering the prompt. Claude Code 2.1.285 has a live `/effort` command; hydra's claude engine passes no effort today.

**Why:** cheaper sessions on easy prompts, more thinking on hard ones.

**How to apply:** first open question is whether `/effort` resets the prompt cache. Measure `cache_creation_input_tokens` on the turn after a flip. Cache reads were about 57% of one session's cost, so if it resets the cache, only flip on confident multi-level jumps (sticky/hysteresis). Don't start without Kevin un-parking it.

**Prior art is not ours (2026-09-30):** `docs/designs/codex-user-message-queue/HANDOFF.md:22` in hydra lists `scripts/jev-routing-backtest.ts` and `scripts/jev-swebench-eval.ts` as dirty files to leave alone. That HANDOFF was authored by sf8193 (commits `1de4661`, `a0e1097` / PR #374), so those were *his* untracked tree. Two independent `find ~ -name 'jev-*'` runs came back empty and no transcript under `~/.claude/projects` mentions them — that is expected, not deletion. Ask Sam rather than searching again.
