---
name: reference_clients_barrel_mock_gap
description: "graph tests mock 'clients' (the barrel); a client imported from 'clients/venture' is a different module path and stays UNMOCKED, making real HTTP calls"
metadata: 
  node_type: memory
  type: reference
  originSessionId: 7cfb79ad-23f4-49ce-95c2-df8be09f146d
  modified: 2026-09-12T15:55:42.275Z
---

Most `graph` tests that exercise an external-call path mock the barrel:
`vi.mock('clients', () => ({ ipseity: {...}, treasury: {...} }))`.

That mock does **not** cover a module imported by its own path. `clients/venture/index.ts` is a
separate module specifier, so `import { findUsersByEmail } from 'clients/venture'` resolves to the
real implementation and issues a **live HTTP request** to `INTERNAL_VENTURE_BASE_URL` during tests.
Symptom: a wall of failures in files you never touched, asserting `expected undefined to match
object { outcome: 'COMMITTED' }`, and it survives running the file alone (so it is not the
fork-partition flake or a stale test DB — see [[reference_graph_tests_need_just]]).

When adding an external client call to a shared service path, grep **every** test that reaches it
(`grep -rln "commitRow\|bulkCommitRows\|forceSyncRow" graph/src --include="*.test.ts"`) and add the
mock to all of them — not just the ones in the suite you happen to run. On the matchmaking commit
path that was 4 files: `commitRow`, `commitLifecycle`, `forceSyncRow`, `rejectRows`.

Default the mock to the "service knows nothing" answer (e.g. `okAsync([])`). Existing expectations
then pass unmodified, which is also the proof that the change is behaviour-preserving wherever the
new call returns no answer.

Confirm a suspected break is yours by running the same files on the base branch
(`git checkout <base>` and re-run) before blaming the environment.
