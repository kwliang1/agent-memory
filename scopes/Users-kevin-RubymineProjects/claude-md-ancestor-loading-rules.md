---
name: claude-md-ancestor-loading-rules
description: "VERIFIED: an ancestor .claude/ dir contributes CLAUDE.md body + agents/ + skills/ to any session under it, but its @imports are NOT followed — so ~/.claude/CLAUDE.md leaks into every session under /Users/kevin/"
metadata: 
  node_type: memory
  type: reference
  originSessionId: 02f63c5f-16e5-45b3-b8bc-b07eb55a8ec8
  modified: 2026-09-11T18:11:29.335Z
---

Verified empirically 2026-09-11 with synthetic `/tmp` trees + canary strings probed via `claude -p` (not inferred from docs):

| loaded via | `CLAUDE.md` body | its `@imports` | `agents/` | `skills/` |
|---|---|---|---|---|
| config dir (`CLAUDE_CONFIG_DIR`) | yes | **yes** | yes | yes |
| ancestor `.claude/` (walk-up from cwd) | **yes** | **no** | **yes** | **yes** |

A plain `CLAUDE.md` in an ancestor dir also loads. The decisive probe: an ancestor `.claude/CLAUDE.md` containing both a canary line and `@probe-persona.md` yielded the canary but NOT the imported file's canary, even with the import target sitting next to it.

**Consequence for Kevin's box:** `/Users/kevin/.claude/` is an ancestor `.claude/` for every session whose cwd is under `/Users/kevin/`. So regardless of `CLAUDE_CONFIG_DIR`, every such session already loads `~/.claude/CLAUDE.md` (the prefs file) and every skill in `~/.claude/skills/` — that's why bridge sessions can reach `ts-best-practices` and `design-doc-voice` even though those live in `.claude`, not `.claude-byte`. See [[claude-config-topology]].

**Why it matters:** it makes a naive `.claude-byte` → `.claude` merge unsafe for `CLAUDE.md` specifically. Merging the Russell wiring into `~/.claude/CLAUDE.md` would tell *every* session under his home "You are Russell… embody it in every reply", and because ancestor `@imports` aren't followed, `russell-persona.md` would never load — the directive to embody a character with no definition present. `agents/` and `skills/` propagate harmlessly (opt-in, cost only context).

**How to apply:** when consolidating config trees, merge `agents/`, `skills/`, `feedback/`, `projects/`, `file-history/` freely; keep persona/voice wiring OUT of any `CLAUDE.md` that sits in an ancestor of normal work dirs. Scope a persona to bridge sessions via the daemon's spawn prompt / `--append-system-prompt` instead. Also note a fake `$HOME` can't be used to probe this — `claude` reports `Not logged in`; test the ancestor mechanism under the real HOME.

## Hooks are config-dir scoped, and are the way to scope a persona (verified same day)

`settings.json` is read from the config dir only — it is **NOT** walked up like `CLAUDE.md`/`agents/`/`skills/`. Verified: a `SessionStart` hook in a project-level `.claude/settings.json` never executed (no side-effect log entry), while the same hook in the config dir's `settings.json` fired and its `hookSpecificOutput.additionalContext` reached the model. Consequence: `~/.claude/hooks/agents-md-reminder.js` (registered in `~/.claude/settings.json`) does **not** apply to bridge sessions today; it would start firing after a tree merge.

A `SessionStart` hook inherits the session's env, so it can branch: `CHAT_PLATFORM=slack` → inject persona; unset → inject nothing. Verified both branches, and that it fires on `source=startup` **and** `source=resume`. This is the no-code way to scope Russell to bridge sessions in a single merged tree — hydra has **no** `--append-system-prompt`/extra-args support (grep for `append-system-prompt|appendSystemPrompt|EXTRA_ARGS|extraArgs|CLAUDE_ARGS` → zero hits), so the CLI-flag route would require a hydra commit.

`CHAT_PLATFORM` is the right marker: it is set on the byte (`HYDRA_ROLE=main`) **and** exported to every spawned session by `buildSpawnEnv` (`daemon/session-lifecycle.ts:126-134`), so one test covers both. Caveat: the hook re-injects on each resume, accumulating persona text in long transcripts (context cost only).

Probing note: a fake `$HOME` breaks auth (`Not logged in`); a throwaway `CLAUDE_CONFIG_DIR` works if you copy `.claude.json` into it.

Related: [[claude-config-topology]], [[hydra-hardcoded-claude-config-paths]].
