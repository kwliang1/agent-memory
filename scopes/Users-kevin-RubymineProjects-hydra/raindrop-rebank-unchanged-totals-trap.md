---
name: raindrop-rebank-unchanged-totals-trap
description: A usage read that reports restarted=true with unchanged totals makes raindrop forget the baseline, emit nothing, bank nothing — the NEXT tick's spend is lost as a cold start
metadata:
  type: project
---

`daemon/raindrop.ts` calls `forgetDelivered` on `restarted`, then returns `[]` when totals didn't move — so nothing is re-banked and the following tick reads as coldStart with delta 0. Any new re-bank trigger must only fire when totals actually change. Found in PR #422 (subagent drain) gate rounds 6–7 for zero-token heals and empty-truncated subagent files; the same trap exists pre-existing for a parent rotation with byte-identical totals.

**How to apply:** when reviewing or adding a `restarted` path in any usage adapter, check it also changes the cumulative. See [[raindrop-usage-live]].
