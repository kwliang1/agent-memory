---
name: nova-build-worktree-screenshots
description: "When spawning nova build sessions, use the repo worktree-dev skill (full infra) and require UI screenshots for FE changes"
metadata: 
  node_type: memory
  type: feedback
  originSessionId: 74df7565-7856-4e0c-96cf-2772ee7c849d
  modified: 2026-08-17T23:24:43.685Z
---

For `build-wt: nova …` builds (nova repo = graph/ + app/ monorepo), when spawning the builder:
- **Use the repo-level `worktree-dev` skill** (`nova/.claude/skills/worktree-dev/SKILL.md`) — `just worktree-init -n <name> -b <branch>` then `just dev up`, which provisions docker/DB/ports and a running app. Do NOT use hydra's bare `worktree` param or copy to /tmp — a bare nova checkout lacks `.npmrc`/`.env`/containers and won't build/test/run (see nova AGENTS.md "Worktrees").
- **If the change involves FE, Kevin wants screenshots of the new UI(s).** BUT a spawned worker canNOT drive Claude-in-Chrome — it boots `--no-chrome` (see [[hydra-chrome-spawn]]), so it has no `mcp__claude-in-chrome__*` tools. The workflow that actually works (2026-08-11): the builder runs `just dev up` and, once its change renders, posts INTO ITS THREAD (a) the local app URL/port and (b) the exact route + how to reach the relevant state (seed steps / an existing seeded record). Then the **main session (browser-capable) drives Chrome against the running worktree** (localhost, same machine) to capture before/after and attaches them via `reply(files:[...])`. Bake this hand-off into the spawn topic — don't tell the worker to screenshot itself; it can't.

**Why:** Kevin stated both explicitly (2026-08-05, NOVA-3718). Nova UI must use ADAPT; screenshots verify the real rendered UI, not just code.

**`factory_build` (the daemon build→adversarial-review pipeline) can NOT be driven from the main/byte session** — it forks the *caller's* session into a builder, and the control session isn't a forkable registry entry → errors `factory_build failed: session not found` (hit 2026-08-17 on NOVA-3849). To get the real factory: either the user sends `build-wt: … execute … ` INSIDE A THREAD (daemon intercepts build-wt→factory only when `msg.isThread`), or a spawned (registered) worker invokes `factory_build` itself. From main, fall back to a normal `spawn_session` build worker with the N-round adversarial review loop baked in (functionally equivalent), and tell Kevin the limitation + the in-thread route.

**`build-wt:` trailing number = REVIEW ROUNDS** (repo-agnostic). Kevin writes e.g. `build-wt: treasury 3 execute BANK-1787` / `build-wt: nova 5 …` / `build-wt: ipseity 1 …` — **Corrected 2026-08-19 by Kevin:** the number is how many *successive clean* review rounds he wants, NOT a ceiling on rounds. The earlier reading below is wrong, kept only for provenance.

~~the number after the repo is how many independent review-agent rounds he wants (bigger/riskier work → more). Confirmed consistent across many builds (1/2/3/5) with no correction after I flagged my reading once. Bake it into the spawn as "up to N review rounds, 2 successive clean before push." (Watch for the occasional typo where it reads as a word, e.g. "nova 2 address" = "to address" — but default to review-rounds.)~~

**How to apply:** bake both into the spawn topic for any nova build. Pull the Linear issue first for `gitBranchName` (branch = `kevinliang/nova-XXXX`). Related: [[bridge-state-recovery]]. Note: `build-wt:` (and `build`, `build_v2`, `/review`, `design:`) are THREAD-SCOPED — the daemon only intercepts them when `msg.isThread` (gated in `daemon/router.ts` ~line 480). Sent in the main DM they fall through to main (me), which is why Kevin's `build-wt:` never auto-fired and I spawn them directly via `spawn_session`. To have the daemon run the real build→review pipeline, `build-wt:` must be sent INSIDE a thread. `spawn:`/`recover`/`health` are not thread-gated, so they work in the main DM.
