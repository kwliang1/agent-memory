---
name: feedback-status-update-each-step
description: "On the bridge, send Kevin a short status reply after every completed step of a multi-step task, not only at the end"
metadata:
  node_type: memory
  type: feedback
  originSessionId: 31cbded6-21f5-49f2-9081-003ae1daa73f
  modified: 2026-10-10T22:16:28.303Z
---

Kevin asked (2026-10-10, daedalus gate): "Provide status updates after each step please."

**Why:** long gate/build runs went quiet between the greeting and the final report; he can't see the transcript.
**How to apply:** after each step finishes (checks run, verifier back, each gate round, push, PRs opened), send a 1-2 line `reply`: what finished, the result, what's next. Keep within [[kevin-prefers-concise-ops-replies]].
