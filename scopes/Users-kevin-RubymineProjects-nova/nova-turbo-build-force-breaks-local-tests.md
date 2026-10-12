---
name: nova-turbo-build-force-breaks-local-tests
description: "`just turbo build --force` wrecks the local test env two ways — it wipes the Prisma query engine out of dist/, and it leaves packages/*/dist inconsistent so vitest resolves stale dists over src"
metadata: 
  node_type: memory
  type: reference
  originSessionId: 78274f4f-8db3-4ec3-bf9a-5c8549aba6b3
  modified: 2026-09-19T04:33:25.128Z
---

Running `just turbo build --filter=<pkg> --force` to reproduce a CI build error (the documented
`tsc --noEmit` vs `turbo build` divergence) leaves the local **test** environment broken in two
separate ways. Both produce large numbers of failures in files the change never touched, and both
look like real regressions.

**1. The Prisma query engine disappears.** `packages/prisma`'s `build` is bare `tsc`, which does
not copy the native binary. After a force build, `dist/gen/client/` has the JS but not
`libquery_engine-darwin-arm64.dylib.node`, and ~24 unrelated graph files fail at suite level with

```
PrismaClientInitializationError: Prisma Client could not locate the Query Engine for runtime "darwin-arm64"
```

Repair: `cp packages/prisma/src/gen/client/libquery_engine-*.node packages/prisma/dist/gen/client/`
(`pnpm codegen` regenerates into `src/gen`, not `dist/gen`).

**2. `packages/*/dist` goes inconsistent and shadows `src`.** Force-building a subset rebuilds some
workspace dists and not others. vitest then resolves the rebuilt ones, and cross-package imports
break at suite level:

```
Cannot find package 'sqids' imported from packages/std.ts/dist/esm/id/bytes.js
Cannot find package '@angellist/std.ts/guard' imported from packages/core/dist/result/mapErr.js
```

The dep IS installed — it's a resolution flip, not a missing package. Deleting one offending
`dist` just moves the error to the next package.

Repair: `just turbo build` with **no filter** (cached, ~5s) to bring every dist back into a
consistent set. Verified: a file failing with the `sqids` error went to 46/46 immediately after.

**How to avoid it:** reproduce CI build errors with `turbo build`, then run `just turbo build`
(unfiltered) before trusting any local test numbers. Check `find packages -maxdepth 2 -name dist
-newermt <session start>` when unrelated suites start failing at *file* level — file-level failures
across unrelated domains are almost always environment, not code.

Related: [[feedback_stale_turbo_cache]], [[feedback_verify_with_turbo_build_not_tsc_noemit]],
[[nova-tests-self-poison-warm-db]].
