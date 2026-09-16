---
name: graph-tsc-skips-colocated-tests
description: "graph lint:types (tsc --noEmit) does NOT flag type errors in colocated src/**/*.test.ts — run vitest for EVERY changed dir, not just the one you edited, or CI (buildkite) catches stale tests."
metadata: 
  node_type: memory
  type: reference
  originSessionId: 54e023ad-2887-464c-895e-ba8313742df8
  modified: 2026-08-28T01:36:14.034Z
---

`pnpm -C graph lint:types` (= `tsc --noEmit`) passed clean while `data/matchmaking/upload.test.ts` still referenced a **removed** export (`bindUploadIngestFile`) and built rows without a now-required column — i.e. tsc did **not** typecheck the colocated `.test.ts`. Vitest uses esbuild (no typecheck), so a stale test only surfaces as a **runtime** failure when that specific test file runs.

Consequence: local `tsc` + running only the service dir you edited can be all-green while CI (`buildkite/nova`, which runs the full vitest suite) fails on a stale test in a sibling dir. This bit BANK-1919: I ran `services/entityMatchmaking` + the workflow dir but not `data/matchmaking`, whose `upload.test.ts` tested the old data-layer API.

**Rule when changing a data-layer / service surface:** run vitest for **every** dir that references it, not just the one you edited. Grep the touched exports across `*.test.ts` and run those files: `pnpm -C graph test <files>`. Removing or changing a `data/*` export → always run that data dir's tests. See [[matchmaking-pii-scoring-architecture]].
