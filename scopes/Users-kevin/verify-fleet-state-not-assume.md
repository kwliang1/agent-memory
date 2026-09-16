---
name: verify-fleet-state-not-assume
description: Never assert live session/fleet state from memory of what I spawned — always read list_sessions first
metadata: 
  node_type: memory
  type: feedback
  originSessionId: 69d8b83c-f3ea-4100-88e0-384fe2bcfb76
  modified: 2026-08-19T23:01:18.951Z
---

Never claim the current session roster (counts, which names exist, what's alive) from my own memory of what I spawned this session. Always call `list_sessions` (or read the dashboard/`sessions.json`) FIRST and ground the claim in that.

**Why:** On 2026-08-19 I told Kevin there were "three `ember` rows"; he replied "I only see one ember row bro." I was wrong — I'd asserted from memory of my three ember spawns instead of reading the live list. Reality: Kevin actively **kills finished sessions himself** (they vanish from `sessions.json` entirely — no `deadAt`, the record is deleted via killSession), and tmux **names get reused** across spawns. So my mental model of "sessions I spawned" drifts from live state within minutes.

**How to apply:** Before any statement about fleet state — a count, "session X is running," a dup/collision claim, a kill recommendation — run `list_sessions` in the same turn and cite it. Killed/finished work isn't lost: check the thread's last messages (`fetch_messages`) to see what it delivered before it was reaped. This is the fact-based-adversary rule applied to my own claims. See [[bridge-state-recovery]], [[worker-posts-to-main-not-thread]].
