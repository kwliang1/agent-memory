---
name: reference_nova_graph_prod_console_query
description: How to run a one-off read-only Prisma query against nova prod — al console app is `nova-graph`, push a .ts script and run it with npx tsx
metadata:
  type: reference
---

To answer a "check prod" question in nova, don't use the interactive REPL (`just console -p`) —
push a script and exec it:

```sh
al console list -a nova-graph -p                     # confirm a console exists
al console push /tmp/probe.ts /nova/graph/scripts/probe.ts -a nova-graph -p
al console exec -a nova-graph -p -- sh -c 'cd /nova/graph && npx tsx scripts/probe.ts'
al console exec -a nova-graph -p -- rm -f /nova/graph/scripts/probe.ts   # clean up after
```

- The app name is **`nova-graph`**, not `nova`. Pod cwd is `/nova/graph`, there is no `/app`.
- `import { prisma } from 'lib/prisma'` resolves — tsconfig paths work from `scripts/`.
- Default console is read-only, which is what a probe wants; don't pass `-w`.
- Schema traps that cost a round-trip each: `PortalInvite` filters on **`inviteEmail`**, not `email`;
  `DistributionPayment` has **`sentStatus`**, not `state`.
- Pipe through `grep -v '^>>'` to drop the "Waiting for …" banner, and avoid `tail -N` on the
  first run — a Prisma validation error dumps ~60 lines and will push your real output off screen.

Respect [[feedback_no_long_polling_al_console]]: fine for a few execs, never a loop.
Transfer flags per [[feedback_al_console_file_transfer]] — always pass `-a` and `-p`.
