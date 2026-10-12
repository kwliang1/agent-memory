---
name: nova-codegen-order-capital-api-first
description: App codegen "Unknown type" errors come from codegen order — capital-api schema:dump must run before graph schema:dump
metadata:
  type: project
---

`graph/schema.graphql` stitches in Meridian types that originate in `capital-api`, so the dump order is
`pnpm -C capital-api schema:dump` → `pnpm -C graph schema:dump` → `pnpm -C app codegen`.

Run graph's dump first and `app codegen` exits **0** while printing dozens of
`[FAILED] Error N: Unknown type "<MeridianType>"` lines — 48 of them for `SecondaryReadinessCheck` in
one case. The type is defined only in `capital-api/src/internal/models/`, is absent from
`graph/schema.graphql`, and `app/codegen.ts` reads *only* `graph/schema.graphql`, so it looks like a
broken app document from whichever PR added it. It is not: graph's dump was taken before capital-api's.

**Why:** the exit code hides it, and AGENTS.md only documents graph-before-app, not capital-api-before-graph.

**How to apply:** before believing an app-side `Unknown type`, grep the type in `capital-api/src`. If it
lives there, re-dump in the order above and re-run app codegen — the errors go to 0. Related:
[[feedback_stale_turbo_cache]], [[turbo-caches-lint-and-test-results]].
