---
name: graph-tsc-ooms-and-reads-as-clean
description: "graph `tsc --noEmit` OOMs locally (exit 134) without --max-old-space-size=6144, and a grep for 'error TS' reads the crash as zero errors; also rebuild packages/core after switching stacked branches"
metadata: 
  node_type: memory
  type: reference
  originSessionId: 78274f4f-8db3-4ec3-bf9a-5c8549aba6b3
  modified: 2026-09-21T19:40:32.853Z
---

Two ways a graph type-check reports clean while CI fails on the same command.

**1. tsc runs out of memory and the crash looks like success.**
`cd graph && npx tsc --noEmit -p tsconfig.json` aborts with **exit 134** and `<--- Last few GCs --->`
on a default heap. The crash output contains no `error TS` lines, so the usual
`| grep -cE "error TS"` prints `0` and reads as a clean run.

CI does not hit this because `.buildkite/pipeline.rb` sets, for `lint-types-graph`:
```
env: { NODE_OPTIONS: '--max-old-space-size=6144' }
resources: { requests: { memory: '4Gi' }, limits: { memory: '8Gi' } }
```

Always run it the way CI does, and check the exit code, not just the grep:
```sh
cd graph && NODE_OPTIONS='--max-old-space-size=6144' npx tsc --noEmit -p tsconfig.json
```
Real case (BANK-2057): a TS2352 in a new `src/lib/datadog/traceRetention.test.ts` was invisible
locally across several runs and failed `lint-types-graph` on buildkite. Note this also contradicts
the older claim in [[graph-tsc-skips-colocated-tests]] that tsc ignores colocated `*.test.ts` —
`graph/tsconfig.json` includes `src/**/*` and the base config excludes only `node_modules`/`dist`.
Colocated tests ARE checked; the earlier miss was more likely this OOM.

**2. A stale `packages/*/dist` from the other branch in a stack.**
After checking out a lower branch in a stack, `packages/core/dist` still holds the build from the
higher branch. graph then type-checks its own (older) source against newer built types and invents
errors — e.g. `Property 'DOCUMENT_FINALIZING' is missing in type ...` in `graphQLErrors.ts`, on a
branch whose source never had that code. CI is unaffected because it builds each branch from
source.

Repair before trusting the number:
```sh
just turbo build --filter=@angellist/nova-core --force   # or unfiltered `just turbo build`
```

Rule of thumb: on a stacked branch, rebuild workspace packages after every checkout, and treat any
type error naming a symbol that does not exist in the current branch's source as a dist artifact.

Related: [[nova-turbo-build-force-breaks-local-tests]], [[feedback_verify_with_turbo_build_not_tsc_noemit]].
