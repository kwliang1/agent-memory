---
name: nova-cdc-changes-system
description: "How nova rows show up in changes.internal.angellist.com (CDC) — blacklist scope lives in infra not nova, is forward-only/not retroactive, and REPLICA IDENTITY FULL is the only nova-side knob"
metadata: 
  node_type: memory
  type: project
  originSessionId: 72b48916-99d0-45c4-b40d-cd6e2845cd53
  modified: 2026-08-04T23:23:08.555Z
---

**changes.internal.angellist.com = Changes CDC** (Debezium logical-replication of Postgres WAL → Kafka → OpenSearch/S3), one index per schema: `cdc.nova.public`. Captures *what* changed; a `_cdc_context` table (txid→actor) supplies *who*.

**What controls whether a nova table is captured ("public"):** the **infra** pulumi file `angellist/infra:pulumi/kafka/Pulumi.prod-us-west-2.yaml`, pipeline `name: nova`. NOT a nova-repo config. `nova:scripts/cdc-config.yaml` is only a **mirror** of that infra block, consumed by the `.github/workflows/cdc-audit.yml` PR audit (`scripts/cdc-audit.ts`) — editing it changes nothing in prod.

**Whitelist → blacklist flip (infra PR #705, merged 2026-08-04 03:29Z):** nova WAS a `tablesInclude` whitelist covering only `data_room.*, file, integration.*, investment_terms, organization.*, transaction.*`. #705 changed it to `tablesExclude` (blacklist: capture everything except api_idempotency, email_send, _prisma_migrations, feature_flag, merge_audit, organization_{api_key,hmac_key,private_jwk,public_jwk}, integration_credential; plus columnsExclude for updated_at/last_used_at/password/token/secret/key patterns). So `directory_entity` and all `distribution*` tables became in-scope only as of #705 — before that they were never captured. (The comptroller pipeline in the same file still uses `tablesInclude` incl. `distributions`/`distribution_actions` — those are comptroller's DB, a red herring when grepping.)

**Nova-side pieces (all merged 2026-08-04):** `_cdc_context` table + `capture_cdc_context()` AFTER-STATEMENT trigger auto-attached to every public table via event trigger (migration `20260729120000_add_cdc_context`, PR #9148); prisma extension `packages/prisma-extensions/src/cdcAttribution/*` sets `app.actor`/`app.metadata` per write-txn (classify.ts errs toward "write"); Temporal `pruneCdcContext` schedule ages rows out.

**CDC is NOT retroactive** (the recurring gotcha — Kevin hit it 2026-08-04): Debezium streams WAL forward from when the connector picks up the new scope; adding tables to an already-running connector does **not** auto-snapshot them. Pre-existing rows never appear until (a) the row is written/updated post-cutover, or (b) someone triggers an **incremental snapshot** signal (a connector/infra op, not nova). Attribution trigger likewise only fires on writes after it was applied. Config-merged ≠ deployed — takes effect on next `pulumi up` + connector restart.

**Only genuine nova-only knob = `REPLICA IDENTITY FULL`** per table (a one-line migration, e.g. `ALTER TABLE directory_entity REPLICA IDENTITY FULL;`). Default replica identity puts only the PK in the *before* image, so UPDATE/DELETE events show new values but no diff / no deleted-row contents. Precedent migrations: `20250919180739` (vehicle_entity_directory_entity_link), `20250919194334` (vehicle_entity_data_room_link). It does NOT affect *whether* a table is captured — only the fidelity of update/delete events.

Owner/context: Cameron Austgen (caustgen) drove the integration; Slack thread C09MU7S0RA4 p1785321937976749. Specs: `angellist/changes` `docs/integration-guide.md` + `specs/attribution.md`. Reference impl: `angellist/fin:pkg/cdc`.
