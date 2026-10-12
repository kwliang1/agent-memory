---
name: nova-savepoint-tests-need-real-failing-sql
description: "Testing nova savepoint/abort recovery — a mocked err-Result never aborts the tx, so the test passes without the rollback; inject a real failing statement instead."
metadata: 
  node_type: memory
  type: feedback
  originSessionId: ca52b8bd-f630-4b73-90ca-325c3713527d
  modified: 2026-09-16T23:31:39.951Z
---

A nova graph test that stubs a data-layer call to return `errAsync(...)` does **not** abort the
Postgres transaction. Code that swallows that error then looks correct, while in production the
failed statement leaves the tx aborted and the next write fails anyway.

Inject a genuinely failing statement on the same tx client instead:

```ts
resultFromPrisma(prismaClient.$executeRaw`SELECT 1 / 0 WHERE ${failure} IS NOT NULL`)
```

**Why:** I shipped a "degrade instead of failing" fix for the matchmaking owner-grant probe
(nova#10197) whose test stubbed an err-Result. It passed; the real path still parked the row in
terminal FAILED because there was no `ROLLBACK TO SAVEPOINT`. Bugbot caught it. The correct
pattern was already in `commitLifecycle.test.ts` one file over, with a comment I had written
saying exactly this.

**How to apply:** any time the code under test recovers from a DB error *and keeps using the same
transaction*, the test must use a real failing statement, and mutation-check by deleting the
rollback. If deleting the rollback still passes, the test is theatre.

Related: [[nova-fsm-stored-definition-not-authoritative]].
