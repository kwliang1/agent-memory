---
name: reference-graph-tests-need-just
description: "Running graph vitest without `just` loses the dotenv and fails as \"TypeError: Invalid URL\", not as a missing-env error"
metadata: 
  node_type: memory
  type: reference
  originSessionId: 3052ff82-3e3d-4fce-9710-81670dc4c7d7
  modified: 2026-09-11T23:22:42.616Z
---

Always run graph tests through `just tt graph <file>`, never `npx vitest --run <file>` directly.
`just` loads `.devcontainer/.env`; a bare `npx vitest` does not, so `config.POSTGRES_URL` is the
unexpanded `postgresql://nova:${POSTGRES_PASSWORD}@...` and the run dies at
`graph/src/lib/prisma.ts` with `TypeError: Invalid URL` before any test executes.

Why it matters: the failure prints as a suite-level FAIL with "Tests no tests", which looks
identical to a real collection error. I used a bare `npx vitest` run as the control in a
"is this flake pre-existing?" experiment, concluded wrongly, and told Kevin so.

Two other things that mimic a real failure in that directory, both confirmed by experiment:
- **Fork-partition sensitivity.** `src/services/entityMatchmaking` has a latent timing flake that
  fires once the directory holds 22+ test files under the default 4 forks. Adding a *trivial*
  dummy 22nd file reproduces it, so a new test file is not the cause. Not reproducible in the
  full `just tt graph` run, which partitions differently.
- **Test-DB pollution.** After ~15 repeated runs, unrelated suites start failing. Recreate rather
  than debug: drop/create `nova_<worktree>_test`, then `POSTGRES_URL=<...> npx prisma migrate
  deploy` from `packages/prisma`.

Control experiments for "is this failure mine?" must hold the runner constant — move the file
aside and re-run the *same* `just` command. See [[feedback-ci-bisect-verify-against-green]].
