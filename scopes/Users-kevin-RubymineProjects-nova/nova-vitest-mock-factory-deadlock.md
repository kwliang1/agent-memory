---
name: nova-vitest-mock-factory-deadlock
description: "A vi.mock factory that dynamically imports a shared fixture deadlocks collection if that fixture's graph reaches the mocked module — silent hang, no error"
metadata: 
  node_type: memory
  type: project
  originSessionId: 08cf2fea-3b12-430e-ad38-6ccdc2eb73db
  modified: 2026-09-17T17:03:36.358Z
---

In nova `graph/`, sharing a `vi.mock('clients')` bank across suites needs the bank in a module whose **only** import is `vitest`. `vi.mock` hoists above imports, so the factory must resolve the bank with `async () => (await import('./x')).bank` — and if `./x`'s import graph reaches `clients`, the factory awaits the module it is mocking.

Failure mode is a **silent hang**: `RUN v3.2.4` prints, zero tests are collected, no error, forever. `testTimeout` never fires because collection never finishes. Observed path: `commitForTest.ts` → `./drive` → `services/fsm/entityMatchmaking` → `gatherPortReads.ts:4` `import * as clients from 'clients'`.

A *type-only* import is safe (`verbatimModuleSyntax` is off repo-wide, so esbuild erases it), which is why the guard comment says "value import".

**Why:** cost ~15 min of debugging a suite that looked like an infra failure, and the class of error never appears in `tsc` — only at test runtime.

**How to apply:** when extracting a shared `clients` mock, put the `vi.fn()` bank in its own leaf module and keep helpers that need `data`/`lib/prisma`/`./drive`/`test/factories` in a separate file. See `graph/src/services/entityMatchmaking/clientsMockForTest.ts`. Related: [[nova-src-must-not-import-test-factories]], [[reference_clients_barrel_mock_gap]].
