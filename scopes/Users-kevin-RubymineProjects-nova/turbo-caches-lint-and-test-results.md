---
name: turbo-caches-lint-and-test-results
description: "just turbo lint:types AND just turbo test both replay cached results — turbo.json declares no `inputs`, so the cache key misses the gitignored generated state that decides the verdict. Use bare tsc and --force."
metadata:
  node_type: memory
  type: reference
---

`turbo.json` gives `lint:types` `dependsOn: ["codegen", "^build"]` and **no `inputs`**, so its cache
key hashes only git-tracked files. The state that actually decides the verdict —
`graph/schema.graphql`, `graph/test/types/gen/`, `packages/prisma/src/gen/client` — is all
gitignored, so a cache hit replays a stored exit-0 and its stdout **without invoking tsc at all**,
and a change in generated state cannot invalidate it.

`just turbo test` does the same: a run reported `FULL TURBO, 1 cached, 132ms` and replayed a stored
`329/329`; the same command with `--force` ran for real.

Cost when it bit: `just turbo lint:types --filter=graph --only` reported clean while the branch had
two genuine `error TS2345`s in files the commit didn't touch (stale literals for two types it had
widened with required keys). Reported "typecheck clean" to Kevin on that basis; a reviewer running
bare tsc found them. Vitest strips types via esbuild, so tests are green either way — only the
typecheck catches that class.

**Do:** `cd graph && NODE_OPTIONS='--max-old-space-size=8192' npx tsc --noEmit` for typechecking,
and `just turbo test --force ...` for any test number you intend to report. Filter tsc output for
your own files — a worktree typically carries 30-60 pre-existing stale-prisma/codegen errors.

Related: [[graph-tsc-skips-colocated-tests]] is the *opposite* claim and is wrong for the default
`graph/tsconfig.json`, which includes `src/**/*` and `test/**/*`. The build config excludes tests;
`lint:types` does not. Also [[feedback_stale_turbo_cache]], [[feedback_verify_with_turbo_build_not_tsc_noemit]].
