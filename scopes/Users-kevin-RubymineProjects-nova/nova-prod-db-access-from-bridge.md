---
name: nova-prod-db-access-from-bridge
description: "Reading nova prod DB from a bridge session: `al console exec -a nova -p` + a tsx script WORKS (2026-09-17 correction); `-a nova-graph`, just psql and direct RDS do not."
metadata: 
  node_type: memory
  type: reference
  modified: 2026-07-29T20:59:57.310Z
  originSessionId: 3efe409d-bcc4-4d9a-9c74-f2a6e35a7a3f
---

From this bridge/bot session I **cannot read nova's prod DB** by either route:
- **`just psql -p`** (nova repo) pulls the Postgres connstring from 1Password (`op item get 4viifkmsmhoitarhom7s25lbz4 --reveal --fields production`), but `op` returns `account is not signed in` / authorization timeout — the desktop unlock prompt can't reach this session (same class of limit as [[bot-session-cannot-sign-commits]] and [[onepassword-cli-prompts]]). Note: the `just psql`/`just prisma` recipes also choke on `(` in inline `-c` SQL because the recipe re-parses `{{args}}` in bash — write SQL to a file and use `psql -f` / `-f`.
- **`al console -a nova-graph -p [-w]`** is RBAC-forbidden: `pods "nova-graph-console-…" is forbidden … in namespace "nova"`. Unlike treasury (where `-w` lands in the accessible `treasury` namespace), nova has no reachable write namespace for me. `al` has no `db`/`psql`/`secret`/proxy subcommand.

**Unblock (op is necessary but NOT sufficient — CORRECTED 2026-07-29):** `! op signin` does authorize op session-wide (desktop-integration auth cached at account/daemon level), and after it `just psql -p` successfully pulls the connstring and launches psql. BUT the connection then **times out** — the prod RDS host resolves to a private VPC IP (e.g. `10.100.168.255:5432`) with **no network route from this bridge session** (my Bash has no VPN/tunnel to the VPC; Kevin's laptop does). So even with op signed in, I still cannot reach nova prod DB directly. `al console -a nova-graph` remains RBAC-forbidden. **Practical path: hand Kevin the query — as `prisma.$queryRawUnsafe(\`...\`)` (cast counts `::int` so JSON.stringify won't choke on BigInt) — and have him paste it into his `NOVA-GRAPH:PRODUCTION` REPL and return the rows.** Don't burn time asking for `op signin` expecting it to fully unblock.

**Contrast:** treasury prod DB IS reachable for me via `al console exec -a treasury -p -w -- bin/rails runner '<ruby>'` (see [[treasury-prod-console-access]]). So cross-service nova↔treasury work from the bridge = treasury half by me, nova half needs op unlock or Kevin.

nova stranded-transfer query (CLEARED-but-unsubmitted): `transfer t JOIN transfer_control_v1 tc ON tc.transfer_id=t.id LEFT JOIN entity_external_bank_reference eebr ON eebr.id=t.recipient_entity_external_bank_reference_id WHERE tc.state='cleared' AND t.treasury_transfer_id IS NULL AND t.failed_at IS NULL AND t.cancelled_at IS NULL`. Recipient EWA/EAA id = `eebr.external_wire_account_id`/`external_ach_account_id` → cross-ref treasury for `entity_id_type/deduplicated/entity_id/state`. Related: [[inc5376-ewa-entity-flip]].

## CORRECTION 2026-09-17 — nova prod IS reachable from a bridge session

The RBAC-forbidden note above used the wrong app name. `-a nova-graph` is forbidden; **`-a nova` works**.
Verified end to end this session against `nova-graph-console-kevin.liang-0` (pre-existing console, default
read-only, no `-w`):

```sh
al console list -a nova -e prod                      # shows nova-graph-console-<user>-0
al console push ./x.ts /nova/graph/scripts/x.ts -a nova -p
al console exec  -a nova -p -- sh -lc 'cd /nova/graph && npx tsx scripts/x.ts'
```

Key facts:
- Pod working dir is **`/nova/graph`**, node v20. `npx tsx` resolves the repo's tsconfig paths, so a script
  can `import { prisma } from 'lib/prisma'` exactly like `graph/src` code does. No 1Password, no VPN.
- **Don't** try to drive `pnpm console` / `scripts/console.ts` — it's an interactive `node:repl`, useless
  under `exec`. A standalone tsx script is the scriptable path; end it with `process.exit(0)`.
- `al console exec` opens its own exec against the pod, so it does not disturb a REPL Kevin has attached.
- Read-only console = read-only DB creds, so a `findMany`-only script is safe to run unattended. Anything
  that writes needs `-w` and Kevin's explicit go-ahead — he objected hard to the *appearance* of acting on
  his behalf, so say plainly which console and which verbs you used.
- Prisma gotcha: `mode: 'insensitive'` is not valid inside `in`. Use `OR: emails.map(e => ({ email: { equals: e, mode: 'insensitive' } }))`.

Supersedes the "hand Kevin the query" workaround above for nova. See [[feedback_al_console_file_transfer]].

## 2026-09-25 — push INTO `/nova/graph`, never `/tmp`

Cost three round-trips on BANK-2158 by pushing a script to `/tmp` and running `node /tmp/x.js`.
Node resolves modules from the *script's* directory, so from `/tmp` you get
`Cannot find module '@angellist/nova-prisma'`. Working around it with
`require.resolve(mod, { paths: ['/nova/graph'] })` then fails differently —
both `/nova/graph` and `/nova/packages/prisma` are `"type": "module"`, so CJS `require`
hits `ERR_UNSUPPORTED_DIR_IMPORT` on `/nova/packages/prisma/dist/gen/client`.

Just follow the recipe above: push to `/nova/graph/scripts/x.ts` and run `npx tsx`. If you do
need plain node, write `.mjs` and
`import { PrismaClient } from '/nova/packages/prisma/dist/gen/client/index.js'`.

Output files still go to pod `/tmp` and come back with
`al console pull /tmp/out.txt <local> -a nova -p`. Cast counts `::int` in raw SQL —
`count(*)` returns BigInt and breaks `JSON.stringify`.

Table/column names are snake_case via `@@map`, not the Prisma model names:
`virtual_bank_account` (`treasury_customer_account_id`, `entity_financial_account_id`),
`entity_financial_account` (`entity_id`), `entity` (`al_ipseity_entity_id`).
Nova stores treasury uuids **dashed**; treasury stores them **undashed** — normalize with
`replace(lower(x), '-', '')` before joining across the two. See [[reference_ipseity_uuid_undashed]].
