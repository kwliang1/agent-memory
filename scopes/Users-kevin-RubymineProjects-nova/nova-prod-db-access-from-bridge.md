---
name: nova-prod-db-access-from-bridge
description: "The bridge/bot session cannot read nova prod DB — op is not signed in (just psql fails) and al console -a nova-graph is RBAC-forbidden in namespace \"nova\"."
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
