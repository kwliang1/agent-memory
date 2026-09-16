---
name: reference_matchmaking_pii_temporal_gate
description: The matchmaking scoring PII gate is GONE — scoring now passes rowNumbers, not PII, to Temporal
metadata:
  node_type: memory
  type: reference
  originSessionId: 42d5578e-1336-4a70-a1fd-7bf465b42836
  modified: 2026-09-12T00:00:00.000Z
---

**Superseded as of 2026-09-11 — the old advice is now wrong.** Matchmaking scoring used to hand raw
PII (TIN/legalName) to the `scoreMatchmakingBatch` Temporal workflow, which persists workflow input
in event history durably and unencrypted, so it was gated OFF behind `config.MATCHMAKING_SCORING_ENABLED`
until an encrypting payload codec landed.

That is no longer the design. #9774 (`8963021b3b`, "reference-passing scoring so no PII rides
Temporal") made the workflow carry **rowNumbers only** — the activity re-parses the source file and
joins on the stable `(uploadId, rowNumber)` key. With no PII on the payload the gate had nothing to
guard, and #10003 (`ae99cd2241`) removed it. `grep MATCHMAKING_SCORING_ENABLED graph/src` returns
nothing on main; only two dead entries remain in `graph/config/configtool/*/config.yaml`.

**How to apply:** do not look for a scoring gate in `stage.ts`/`prepareBatch.ts` — there isn't one,
and scoring is live in staging and prod. If a future change puts PII back on a Temporal payload,
that is the thing to object to, not a missing flag.

Related: [[reference_treasury_transfer_state_machine]].
