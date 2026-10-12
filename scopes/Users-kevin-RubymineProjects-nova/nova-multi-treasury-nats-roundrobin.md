---
name: nova-multi-treasury-nats-roundrobin
description: "Several treasury worktree containers on one NATS round-robin Prophet calls across SEPARATE MySQL DBs — a nova worktree's treasury reads hit the wrong DB ~(n-1)/n of the time and silently mis-score"
metadata:
  node_type: memory
  type: project
  originSessionId: ac78a74b-2faa-4731-aad4-1cab26e3e3d1
  modified: 2026-09-24T22:35:00.000Z
---

**Every running `treasury*` container subscribes to the same local NATS, so Prophet queue-groups
them and a nova call lands on a random one.** Each has its OWN MySQL DB
(`treasury_development`, `treasury_development_<worktree>`, …), so a lookup only succeeds when
it happens to hit the DB that holds the data.

Measured 2026-09-24 with 4 treasury containers up: `listCustomerAccountsByEntity` for a seeded
entity returned **1 account on 2 of 8 calls, 0 on the other 6** — clean ~1-in-4. After stopping
the three others: 8/8.

**Why it's nasty:** nothing errors. Matchmaking scored a whole batch with
`"The matched entity has no investment wallet in Treasury"` on rows whose wallets existed and
were verified+active. It reads as a data/seed bug, not a routing one.

Diagnose (don't infer — measure):
```
for c in $(docker ps --format '{{.Names}}' | grep '^treasury'); do
  echo -n "$c: "; docker exec $c sh -c 'cd /app && bin/rails runner "print ActiveRecord::Base.connection_db_config.configuration_hash.values_at(:host,:port,:database).inspect"'
  echo; done
```
Then loop the client call ~8× from `graph/` and count hits; a mixed result is proof.

Fix: `docker stop` the other `treasury*` containers for the duration. Worktree treasury DBs are
usually **empty** (`CustomerAccount.where(account_purpose:'INVESTMENT').count == 0`) — check that
first, it makes stopping them obviously safe. Restart them after.

`seedMatchmakingLocalDemo.ts` hardcodes container `treasury`, so its wallet links only ever land
in the main one. ipseity has a single container (`ipseity-app-1`), which is why TIN lookups stay
consistent while treasury reads flap — that asymmetry is the tell.

See [[nova-matchmaking-local-e2e]], [[nova-entity-matchmaking-scorer]].
