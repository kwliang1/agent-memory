---
name: reference-app-tests-need-just-turbo
description: "app tests must run via `just turbo test --filter=app`, never bare `npx vitest` — the dotenv flips code paths and hides real failures"
metadata: 
  node_type: memory
  type: reference
  originSessionId: 78274f4f-8db3-4ec3-bf9a-5c8549aba6b3
  modified: 2026-09-12T00:52:06.624Z
---

App (`app/`) tests must be run with `just turbo test --filter=app --only -- <path>`, never a bare
`npx vitest run` from `app/`. `just` loads `.devcontainer/.env`; a bare vitest run does not, and the
difference silently changes which branch production code takes.

Concrete case (2026-09-11, BANK-2057): `app/lib/apollo.ts`'s `reportApolloError` picks one of three
sinks — `console.error` when `isDevelopment`, `datadogRum.addError` when `isBrowser`, else a stdout
JSON line. Under bare `npx vitest` the RUM branch ran and a new test passed 4/4. Under
`just turbo test` the dotenv made `isDevelopment` true, the report went to `console.error` (swallowed
by an existing `beforeEach` spy), and the same test was **red**. A reviewer caught it; my own run had
said green.

Two lessons:
- Assert against the behaviour, not one sink. Collect from every sink the code can use.
- **Mutation-test results from bare `npx vitest` are not trustworthy either** — re-run the battery
  under `just` before believing a predicate is covered.

This mirrors the same rule for graph in [[reference_graph_tests_need_just]].
