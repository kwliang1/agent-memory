---
name: feedback_dont_ask_gate_handoff_midgate
description: "Once a gate is underway in a session, don't stop to ask Kevin whether to hand off — keep running rounds in place"
metadata:
  node_type: memory
  type: feedback
  originSessionId: c51efd44-05db-438e-8e0f-f7f9fd158611
  modified: 2026-10-30T21:00:59.316Z
---

2026-10-30 (treasury BANK-2505, round 7): I paused the gate to ask "hand off or keep going?" after round 6. Kevin: "keep going. don't ask again".

**Why:** the pause stalled the gate waiting on him; the cost saving from [[feedback_gate_in_fresh_session]] isn't worth an interruption once rounds are running.

**How to apply:** offer a handoff at most once, before round 1 (per CLAUDE.md step 0). After the gate starts, keep running rounds in the same session without asking.
