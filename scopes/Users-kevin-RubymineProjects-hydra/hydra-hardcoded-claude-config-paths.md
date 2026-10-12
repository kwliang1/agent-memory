---
name: hydra-hardcoded-claude-config-paths
description: "hydra's ~/.claude vs ~/.claude-byte config split: 3 read paths hardcode .claude, and failed resumes poison thread history with no-UUID tombstones (the real 2026-09-11 blocker)"
metadata: 
  node_type: memory
  type: project
  originSessionId: 02f63c5f-16e5-45b3-b8bc-b07eb55a8ec8
  modified: 2026-09-11T18:01:44.174Z
---

Two distinct hydra bugs, found 2026-09-11 while all 15 bridge sessions were dead. Keep them separate — I initially conflated them and had to retract.

## Bug 1 (the actual recovery blocker): failed resumes poison sessionHistory

`daemon/recovery-selection.ts:7-11`:
```ts
export function recoveryEntry(history) {
  return history.findLast(entry => !(entry.model === 'codex-default'
    && entry.engine !== 'codex' && !entry.codexThreadId && entry.messageCount === 0))
    ?? history.at(-1)
}
```
Every failed resume **appends a tombstone** entry to `thread.sessionHistory`: `claudeSessionId=null, messageCount=0`, but `model` is the real model (e.g. `claude-opus-5[1m]`), not `codex-default`. The filter only skips codex-default junk, so `findLast` returns the tombstone. Then `daemon/commands/thread.ts:329` (`if (claudeSessionId || codexThreadId)`) is false → **tiers 1 and 2 are skipped entirely** → tier 3 respawn = thread history only, full context lost. Each retry appends another tombstone, so retrying makes it worse.

The good UUID sits one or two entries back. Fix (a): extend the predicate to also skip `messageCount === 0 && !claudeSessionId && !codexThreadId`. Fix (b): prune trailing null entries from `threads.json` — faster but leaves the bug armed.

## Bug 2 (separate, not the blocker): hardcoded `.claude` reads

`daemon/config.ts:35` has the right helper (`CLAUDE_CONFIG = process.env.CLAUDE_CONFIG_DIR || join(homedir(), '.claude-personal')`) and spawn paths use it (`session-lifecycle.ts:131`, `engines/claude-engine.ts:33`). But three **reads** hardcode `join(homedir(), '.claude', …)`:
- `daemon/session-lifecycle.ts:913` → `~/.claude/sessions/<panePid>.json`
- `daemon/session-lifecycle.ts:923` → `~/.claude/projects/<cwd-slug>/<uuid>.jsonl`
- `daemon/observability.ts:13` → `PROJECTS_ROOT = ~/.claude/projects`

First two are inside `discoverClaudeSessionId()`, the missing-UUID self-heal, so it returns null for every byte-era session; observability reads a 29M tree instead of the real 1.4G one. Real bug, but tier 1 never calls discovery when the UUID is already in thread history — so this did NOT cause the outage.

## The config split itself

Daemon runs `HYDRA_STATE_DIR=~/.claude/channels/slack` but launches sessions with `CLAUDE_CONFIG_DIR=~/.claude-byte` — bookkeeping in one tree, conversations in the other. Only in `.claude-byte`: `CLAUDE.md` (997B Russell wiring), the 4 `*-persona.md`, `agents/`, `feedback/drafts`, and `projects/` (1.4G, the superset after the port). Only in `.claude`: `channels/`, `daemon/`, `hooks/`, `ide/`, `jobs/`, `plans/`, `tasks/`, `settings.local.json`. Mergeable toward `.claude`; two traps — `CLAUDE.md` genuinely collides (9771B prefs vs 997B wiring, different files same name), and **unsetting `CLAUDE_CONFIG_DIR` yields `.claude-personal`, not `.claude`** (config.ts:35 default).

## Method lessons

- **Don't grep pretty-printed JSON for `"key":"value"`** — `threads.json` has a space after the colon, so my grep reported 0 surviving UUIDs when jq found 111 of 149. I reported that to Kevin as fact and had to retract it. Use jq for structured files, always.
- Kevin caught the config-dir angle himself ("I think you want claude-byte don't you") after I'd misdiagnosed the outage as transcripts merely being in the wrong place — and my recommended port emptied `.claude/projects`, making Bug 2 strictly worse.
- `resume` takes no argument (`daemon/router.ts:534` anchors `/^(?:resume|\/resume)\s*$/i`), so a UUID can't be passed by hand.
- The daemon announces resume success before the process actually dies, so tier-1 failures report as "resumed — full context restored" while `exit_code=1 wall_clock=0s`. Never trust the announcement; check the exit logs.

Related: [[claude-config-topology]], [[disconnected-live-sessions-bridge-death]], [[daemon-restart-via-bash-not-cli]], [[spawned-session-crash-recovery]].


**RETIRED 2026-09-26 — `.claude-byte` is dead.** The whole fleet now runs `CLAUDE_CONFIG_DIR=/Users/kevin/.claude` (Kevin: "billing is incorrect, we should never be using claude-byte anymore"). Every `.claude-byte` claim above is historical. Verified same day: zero `claude-byte` references remain in the repo, `claudeConfigDir()` defaults to `.claude` (the old `.claude-personal` default is gone), and the slack `.env` pins `.claude`. See [[hydra-console-billing]].
