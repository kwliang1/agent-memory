---
name: hydra-codex-sessions-gotchas
description: "Running codex-engine hydra sessions: attach lands on the empty hydra-anchor window (TUI is on window 1), and an out-of-date codex CLI 400s every turn with a model-version error."
metadata:
  node_type: memory
  type: project
---

**2026-09-14 — first codex-engine session ever run on this machine** (`prism`, respawned onto `astra`/gpt-6-astra). Two traps, both cost a round-trip.

**0. Prefer `hydra attach <name>`** — the purpose-built command (`cli/hydra.ts:295`, USAGE line 40). It resolves the session's codexThreadId + socket and runs `codex resume … --remote` with the right CODEX_HOME, landing you straight in the TUI. Disconnect is clean (line 331 swallows the exit). `hydra` is a shell ALIAS for `bun …/cli/hydra.ts`, so it needs an interactive shell. Errors if the session isn't codex or the socket is gone.

**1. `tmux attach -t <name>` looks blank.** A codex session has TWO windows, unlike Claude sessions' one:

```
0: hydra-anchor   active=1   ← bare zsh placeholder, attach lands here
1: hydra-chat                ← the actual codex TUI
```

Fix: `tmux attach -t <name> \; select-window -t 1`, or prefix + `1`. Nothing is broken — read window 1 before diagnosing anything.

**2. An old codex CLI fails every turn with a 400, silently from Slack's side.** Symptom in the `hydra-chat` pane:

```
■ {"type":"error","status":400,"error":{"type":"invalid_request_error",
   "message":"The 'gpt-6-astra' model requires a newer version of Codex. …"}}
```

The session looks healthy from outside — registry says `engine: codex`, `turnState` advances, `codex app-server` and `codex resume` are both running — but it can never answer, so Slack just goes quiet. **Diagnose by capturing window 1, not by process state.**

codex here is a **Homebrew cask**, not a formula (`brew list --versions codex` prints nothing; `/opt/homebrew/bin/codex` → `/opt/homebrew/Caskroom/codex/<ver>/`). Upgrade with `brew upgrade --cask codex`. 0.144.6 → 0.154.0 cleared the gpt-6-astra gate on 2026-09-14.

An upgrade does NOT rescue a running session — the live `codex app-server` is pinned to the old binary. Upgrade, then `kill` + `respawn <alias>` in the thread.

**Aliases** (`shared/constants.ts:31`): `astra`→gpt-6-astra, `sol`→gpt-5.6-sol, `terra`→gpt-5.6-terra, `luna`→gpt-5.6-luna. `resolveProtocolModel` (`daemon/router.ts:70`) tries the Claude table first, falls through to codex, returns `engine:'codex'` — no separate command needed.

**Cross-engine respawn carries no transcript** — `handleForkIntercept` calls it out explicitly. The new session gets the Slack thread at `limit=50` and nothing else: no local files, no memory, no unposted reasoning. Hand it that context in the `respawn <alias>: <topic>` body, since a bare `respawn <alias>` reuses the *original* thread topic (`resolvedTopic = topic || thread?.topic`, `daemon/commands/thread.ts:430`). See [[respawn-must-be-in-a-thread]].
