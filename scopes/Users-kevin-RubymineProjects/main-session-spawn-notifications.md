---
name: main-session-spawn-notifications
description: "This is the `main` Slack bridge session; \"[system] Spawned X\" lines are notifications, not task assignments"
metadata: 
  node_type: memory
  type: feedback
  originSessionId: 77f6b237-62fa-41a6-80e3-a258759c9022
---

In the Slack/Discord bridge, this session is the **`main`** orchestrator (`get_session_info` → `role: main`, cwd is repo root, holds `spawn_session`/`kill_session`). Sub-sessions (nova, drift, spark, pixel, …) are separate sessions with their own contexts, each on its own issue/worktree.

`[system] Spawned <label> for topic: …` lines that arrive in main's context are **notifications that a sub-session was created — NOT task assignments to main.** They land here because main and all sub-sessions share one Slack DM channel.

**Why:** On 2026-06-25 I (main) misread a "Spawned nova for BANK-1470" notification as my own kickoff and did the whole BANK-1470 investigation myself, duplicating the real `nova` session's work. Kevin flagged "it shouldn't have landed in your context."

**How to apply:** When a `[system] Spawned …` line arrives, treat it as FYI only. Do NOT start the work — the named sub-session owns it. Use `list_sessions` to see what's running. Main's job is orchestration (spawn/kill/watch), not doing sub-session issues. If unsure whether a message is for me, check `get_session_info` first.

**Spawn command routing (Kevin keeps hitting this):** `spawn-wt: <repo> <topic>` works at the **top-level DM** and spawns a worktree session. **`build-wt:` NO LONGER EXISTS** (verified 2026-09-15). It was deleted with the v1 protocol in `d7b6f24`; the only remaining hits repo-wide are a test fixture and a stale diagram. Worse than a no-op: typed in a thread it partially matches the build_v2 regex, which captures `-wt` as a model alias, so the daemon replies "Unknown model `-wt`" and stops. Earlier notes here said it was "thread-only" — that was true before the deletion and is now wrong. To spawn for him, use `spawn_session` with `worktree:<repo>` in the topic.

**Coordinating with sub-sessions:** Main has no direct session→session inject tool. Posting into a sub-session's thread via `reply` lands the message in the thread but does **not** wake that session — the daemon drops bot-authored messages (`hydra/daemon/router.ts:295`, `if (msg.isBot) return`). Only a message from Kevin (the allowed user) into a DM thread routes to its session (DM threads are exclusive). So to relay info to a sub-session: post it in the thread for the record, but tell Kevin he must drop a line there (or nudge it) for the session to actually pick it up. The hydra bridge source is `/Users/kevin/RubymineProjects/hydra/` (daemon + per-session `bridge.ts` MCP shim).

**CORRECTION 2026-09-10 — main CAN reach a sub-session directly, via the harness `SendMessage` tool.** The paragraph above ("Main has no direct session→session inject tool… only a message from Kevin routes to its session") describes the *bridge/daemon* path and remains true of it. But the harness exposes `ListAgents` + `SendMessage`, which reach peer Claude sessions on this machine. `ListAgents` lists them as `rubymineprojects-<nn> [ref] · interactive · busy|idle · tmux <name>:@…` — map the tmux label to the hydra session name, then `SendMessage {to: "rubymineprojects-32 [5d3d6a]", message: …}`. VERIFIED working: warned `ember` about its gutted worktree and the send was accepted ("another Claude session on this machine"). Messages enqueue and drain at the receiver's next tool round, so a `busy` peer still gets it. Use this instead of asking Kevin to nudge a session. `notify_when_idle: true` also subscribes to a one-shot idle notice — better than polling `ListAgents`.
