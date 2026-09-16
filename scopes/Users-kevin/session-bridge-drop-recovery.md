---
name: session-bridge-drop-recovery
description: A spawned session's hydra bridge can drop while its process stays alive — how to diagnose (peek) and recover (kill by thread_id + respawn)
metadata:
  node_type: memory
  type: reference
  originSessionId: fde87b20-ecfe-4bab-9071-d6b459035225
  modified: 2026-08-19T01:07:25.210Z
---

Failure mode (seen 2026-08-17, session "scout"/venture #33086 review): a spawned worker's **hydra bridge connection drops while its Claude process stays alive and working**. Symptom Kevin reports: "session X isn't receiving my replies in tmux."

**Diagnose:**
1. `list_sessions` → the broken one shows `status: "disconnected"` while all others are `connected` (session-specific, not a daemon-wide outage).
2. `peek_session(name)` → the tmux is alive (recent output), and **Kevin's last reply is sitting UNSUBMITTED at the `❯` prompt** — the bridge delivered the text to the pane but the disconnected state meant it never got submitted/processed. That un-submitted line at the prompt is the tell.
3. A resourceful worker may notice its own bridge is down and start reading the thread + posting replies via the **claude.ai Slack MCP** (`AngelList - Slack`) instead — so its OUTBOUND analysis still reaches the thread, but the INBOUND (Kevin→worker) path is dead. Don't be fooled into thinking it's fine because replies are appearing.

**⚠️ FIRST — DRAIN THE ORPHANED QUEUE (learned the hard way 2026-08-19).** While a session's bridge is down, inbound messages (Kevin's replies to it) keep QUEUEING in `~/.claude/channels/slack/message-queue.json`, **keyed by the session_id**. If you kill+respawn, the new session gets a NEW session_id, so those queued messages are **orphaned under the dead id and never delivered** — the respawn does NOT inherit the queue. In the scout/#33086 incident, 15 messages (≈9 of them Kevin's real replies, incl. an action "post replies in the PR for 3 and 4") were stranded this way.
So BEFORE killing: `python3 -c "import json;d=json.load(open('~/.claude/channels/slack/message-queue.json'));..."` read the dead session's queued list, extract Kevin's actual messages (records are `{type,content,meta}`; filter out the `[system]`/critic/owner review-orchestration ones), and **carry the still-relevant/actionable ones into the respawn's topic (or relay them into the thread after)**. Don't lose his questions twice (once to the drop, once to the respawn).

**Recover (confirm with Kevin first — it's destructive to in-memory state AND to the queue, per above):**
1. `kill_session({thread_id: "D0BE3RB4Y00:<ts>"})` — kill by thread_id works for a still-registered disconnected session (returns the killed session_id). (An already-terminated session returns "session not found" — already gone, nothing to do.)
2. `spawn_session({chat_id, message_id: "<thread anchor ts>", topic})` — respawn on the SAME thread; recovery preamble: re-read THIS thread (prior analysis is posted there), answer the pending question(s) — INCLUDING the ones you rescued from the orphaned queue — then continue. Use the real bridge (`reply`), not the Slack-MCP workaround.
3. `set_description` + `list_sessions` to confirm the respawn came up `connected`.

There is no lighter "reconnect" tool exposed to main — kill+respawn is the fix. Scratch context is recoverable from the thread, but the **queued inbound messages are NOT** unless you drain them first. Related: [[bridge-state-recovery]], [[worker-posts-to-main-not-thread]].
