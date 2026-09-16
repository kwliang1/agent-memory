---
name: shell-script-review-blind-spots
description: "What shell-script review misses: partial-state checks, docker compose v1 vs v2, and || true hiding side effects"
metadata:
  type: feedback
---


- **Partial-state checks**: When a script checks one service/container to infer the health of an entire stack, flag it. A single-container check can skip startup of other dependent services.
- **CLI version mismatches**: Watch for `docker compose` (v2 plugin) vs `docker-compose` (v1 standalone) inconsistencies, especially when `|| true` silences failures. If diagnostics and teardown use different CLI variants, one path may silently fail.
- **Silent failure with `|| true`**: Any command guarded by `|| true` that produces important side effects (logs, diagnostics) should be scrutinized — the `|| true` can hide real failures.

Relocated 2026-09-16 from the conductor nova-kigali worktree scope, which no session loads.
