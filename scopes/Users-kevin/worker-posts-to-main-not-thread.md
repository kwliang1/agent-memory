---
name: worker-posts-to-main-not-thread
description: Recurring bridge slip — a spawned worker replies to the bare main DM instead of its own thread; how to detect and redirect
metadata:
  node_type: memory
  type: feedback
  originSessionId: fde87b20-ecfe-4bab-9071-d6b459035225
  modified: 2026-08-12T21:45:10.419Z
---

Recurring failure mode on the Slack bridge: a spawned worker session `reply`s to the **bare main DM** (`chat_id="D0BE3RB4Y00"`) instead of **its own thread** (`chat_id="D0BE3RB4Y00:<anchor_ts>"`). Consequences: the worker's status update clutters the main channel, and when Kevin replies to it (e.g. approving an a/b/c options list, or "wrong thread homie"), his reply routes to **main (me)** instead of the worker — so the worker never sees Kevin's answer and I have to untangle it.

Seen ≥2× (2026-08-11 comet posted an a/b/c decision to main; 2026-08-12 bloom posted a CSV-design update to main → Kevin: "wrong thread homie").

**Why it matters:** Kevin gets annoyed, and a blocked worker can stall waiting for an answer that landed with me.

**How to handle when Kevin reacts to a main-posted worker message (or says "wrong thread"):**
1. `fetch_messages(D0BE3RB4Y00, limit ~10)` — the offending update shows as a top-level main message authored by "me" (all sessions share the bot identity, so "me" ≠ this session; content that isn't mine = a worker's).
2. Match the content to a session via `list_sessions` descriptions/threads to identify WHICH worker (e.g. CSV/classifier → bloom; permission-seeder a/b/c → comet). Names reshuffle — match by thread + topic, not name.
3. Relay Kevin's message into that worker's thread: `reply(chat_id="D0BE3RB4Y00:<thread_ts>", ...)`, prefixed "[relayed from Kevin — he replied in the main DM]".
4. Tell the worker to use its thread's chat_id (not the bare main channel) for all future updates, and to repost the stray update in-thread.
5. Confirm back to Kevin in main, pointing at the worker's thread link.

Note: uncertain whether a bot-authored message posted into a worker's thread reliably reaches that worker's stdin — workers often self-correct or had already proceeded. Relay anyway; it's the right record even if the wake is unreliable. Related: [[bridge-state-recovery]] (orphaned/un-threadable messages), [[nova-build-worktree-screenshots]] (build-wt routing in main DM).
