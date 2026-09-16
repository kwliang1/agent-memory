---
name: feedback-stale-turbo-cache
description: "When a single turbo task fails after others cache-hit, suspect stale upstream dist before suspecting source-level bugs"
metadata: 
  node_type: memory
  type: feedback
  originSessionId: 39334df1-0b09-4241-9b9b-2d03ca15ab0e
---

When turbo reports "N-1 of N cached, 1 task failed" and the failing task is a downstream consumer (e.g. `@angellist/capital-api#build` failing with a TS2344 against a type from `@angellist/nova-core`), default to the **stale upstream dist** hypothesis before chasing source-level fixes.

**Why:** Hit this on NOVA-1770. Capital-api's `tsc` failed against a `TaggedError` constraint that "looked wrong" in source. I burned two rounds proposing source fixes (first the wrong package, then the wrong file). User pushed back and asked for fact-check agents — agents proved that `rm -rf packages/<upstream>/dist packages/<upstream>/.turbo && pnpm --filter @angellist/<upstream> build` fixed it, even though the rebuilt `.d.ts` was byte-identical. Turbo's content hashing for the downstream task was tied to a prior `.d.ts` resolution from before an upstream refactor (PR #8130, `match()` on TaggedError) landed. The fix wasn't the file contents — it was forcing the consumer to re-resolve against fresh dist.

**How to apply:**
- First move on a one-task-cache-miss-with-type-error: identify the *upstream* package the failing import chain depends on, then `rm -rf packages/<that>/dist packages/<that>/.turbo && pnpm --filter <that> build`. Re-run the downstream build.
- If the error mentions a type from `@angellist/nova-core` (TaggedError, ResultAsync, etc.), the upstream is `packages/core/` — NOT `packages/core-server/` (different package).
- Don't propose loosening type constraints or rewriting consumer code as a first move when the failure pattern is "this used to compile and now doesn't, only on cache-miss." That pattern points to stale dist, not bad source.
- When uncertain between "stale cache" vs "real source bug": spawn an empirical agent to run the cache-clear sequence and observe whether it fixes the build. Don't reason about it from source alone — TypeScript's resolution behavior with workspace symlinks + stale .d.ts is non-obvious enough that direct measurement beats deduction.
