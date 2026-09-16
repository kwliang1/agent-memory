---
name: prod-query-local-verify
description: "When verifying maintenance task logic, query prod via al console to simulate effects rather than only trusting analytical reasoning"
metadata: 
  node_type: memory
  type: feedback
  originSessionId: 67f9a3fb-33fb-4d59-9010-588c400379a9
---

When writing maintenance tasks that operate on specific prod records (hardcoded IDs), query prod via `al console` to simulate the cash/balance effects of the proposed changes BEFORE committing. Don't trust analytical reasoning alone — compute the actual projected balance from real LE data.

**Why:** On BANK-1550, analytical reasoning about which LEs to create/destroy was wrong for 3 of 5 accounts. The prod verification script caught the errors immediately.

**How to apply:** Write a read-only simulation script that computes the current state + projected effect of each change, push it to the prod console, and run it. Only commit the maintenance task once the simulation confirms the target balance ($0, or whatever the goal is) for every account.
