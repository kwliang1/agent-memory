---
name: nova-src-must-not-import-test-factories
description: "An import from 'test/factories' inside graph/src pulls 61 graph/test files into the PRODUCTION build program — tsconfig.build.json excludes only *.test.ts"
metadata: 
  node_type: memory
  type: project
  originSessionId: 08cf2fea-3b12-430e-ad38-6ccdc2eb73db
  modified: 2026-09-17T17:03:45.940Z
---

`graph/tsconfig.build.json` includes `src/**` and excludes only `**/*.test.ts*`, `**/*.spec.ts*`, `__mocks__`. So a non-`.test.ts` helper under `graph/src/` (the `*ForTest.ts` pattern) is a **program root of the production build**, and tsc follows its imports out of the fence.

Measured properly (an earlier version of this note claimed "61 test files", which was wrong): adding `graph/test/factories/index.ts` as a program root adds ~175 files and **zero `.test.ts`**. What it actually drags is 56 `graph/test/factories/**` modules, 3 JSON fixtures, all of `@faker-js/faker`, and — the real hazard — `graph/test/types/gen/graphql/graphql.ts`, which is **gitignored** (`graph/.gitignore:9`) and only exists after `pnpm schema:dump && pnpm test:codegen`. That makes `graph#build` depend on a gitignored generated test artifact, the "Stale codegen output" failure AGENTS.md documents. `.buildkite/pipeline.rb` states the invariant ("graph's production build excludes tests and tools, so type-check the full program separately"). Correction: `graph#build` is NOT upstream of `app` or `capital-api` — nothing in the repo lists `graph` as a workspace dep, and `graph/package.json:33` depends on `@angellist/capital-api`, so `graph` is a turbo **leaf** and a red `graph#build` does not cascade.

**Why:** a type error in a test factory would redden the production image build (`graph#build`), not just `lint-types-graph`. It does not reach other packages.

**How to apply:** prefer a `__mocks__/` directory for test-only mocks — `graph/tsconfig.build.json` excludes `**/__mocks__/**/*`, so they stay out of the production program entirely (precedent: `graph/src/lib/__mocks__/`, auto-applied by a bare `vi.mock('lib/temporal')`). A `*ForTest.ts` under `src/` does NOT get that exclusion. Where a fixture does live under `src/`, it takes the account as a **parameter** — but note `stageForTest(account, rows, actor)` was already shaped that way before this rule existed, so do not cite the parameter as a fix for it. Verify with
`grep -rnE "from 'test/" graph/src --include='*.ts' | grep -v '\.test\.ts:'` — it should be empty. Importing `vitest` from `src/` is fine and pre-existing. Related: [[nova-vitest-mock-factory-deadlock]].
