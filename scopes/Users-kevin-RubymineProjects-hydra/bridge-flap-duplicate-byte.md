---
name: bridge-flap-duplicate-byte
description: "Daemon \"bridge disconnected/replacing/registered for session X\" flapping in a tight loop = a session spawned with a DUPLICATE bridge byte (2 tmux windows / two `bun server.ts` clients registering the same session_id, livelocking). Diagnosis + fix."
metadata: 
  node_type: memory
  type: reference
  originSessionId: 0e543ade-488f-42be-95ee-8849ec3b5a75
---

**Symptom:** hydra daemon log spams `bridge disconnected / replacing bridge / bridge registered for session <uuid>` in a tight loop, sometimes alternating between two session_ids (their loops interleave — looks like rivalry, but each is **self**-flapping).

**Root cause (seen 2026-07-21, orbit b0c7f4df + prism a21eeaef):** the session spawned with a **duplicate bridge byte** — its tmux has **2 windows** (normal = 1), i.e. two `bun server.ts` clients both registering the *same* session_id; the daemon allows one bridge per session, so each replaces the other forever. Tell-tale: `tmux ls` shows `<name>: 2 windows`, and `correlate <name>` in the log stays `claude=? transcript=pending` (never finishes starting) — pure thrash, no real work.

**Diagnosis:**
1. Map the flapping session_id(s) to names: `pgrep -fl "<uuid>"` (shows the spawn-log path `…/spawn-logs/<name>-<uuid>.log`).
2. `tmux ls | grep <name>` → if it shows **2 windows**, that's the duplicate byte.
3. Confirm no real work: `grep "correlate <name>" ~/hydra-slack-daemon.log` → `transcript=pending`.

**Fix:**
1. Kill the flapping session(s) — `kill_session` by session_id, OR `tmux kill-session -t <name>` directly (the daemon `kill` may time out if the storm has saturated it).
2. The storm can **wedge the daemon's socket-RPC handler**: vitals timer keeps logging but `reply`/`kill_session` hang (bridge outbound is effectively down). If so, restart the daemon via bash `restart-daemon.sh` (see [[daemon-restart-via-bash-not-cli]]) to clear the wedge + re-establish bridges. Sessions persist.
3. Re-dispatch the real work as ONE clean session; verify health: `tmux ls` shows **1 window**, `correlate` gets a real `claude=<pid>`, and **0 flap events** in a 5s window.

Underlying hydra bug worth fixing if it recurs: the spawn path occasionally starts two bridge bytes for one session. Flag to Kevin.

**Log-reading pitfall (bit me 2026-07-27):** `daemon: thread routing` lines carry a big `threadToSession keys=[<every thread id>]` array, so `grep <threadId>` matches lines about OTHER threads that merely list it. To find what a thread actually maps to, match the field precisely: `grep -oE "effectiveThreadId=<chan>:<ts> resolvedThreadId=[^ ]+ mappedSession=[a-z0-9-]+"`. Don't assert a "crossing" from a loose grep — verify against `effectiveThreadId`.