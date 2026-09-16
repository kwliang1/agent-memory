---
name: nova-prisma-default-pool-exhaustion
description: "nova graph/capital-api PrismaClient omits connection_limit, so on 96-vCPU nodes each pod grabs 193 connections and saturates the staging DB, failing dbmigrate."
metadata: 
  node_type: memory
  type: project
  originSessionId: cb2a514a-3d98-4093-a678-72a96428391b
  modified: 2026-09-01T20:10:30.735Z
---

nova staging `dbmigrate` failing with `FATAL: remaining connection slots are reserved for
roles with the SUPERUSER attribute` (seen 2026-09-01) is DB connection exhaustion, not a
bad migration. Re-running or cancelling the Argo sync never fixes it.

Chain:
- `packages/prisma/schema.prisma:16` → `url = env("POSTGRES_URL")`.
- `graph/src/lib/prisma.ts:14` and `capital-api/lib/prisma.ts:3` call `new PrismaClient()`
  with **no `datasourceUrl`**, so no `connection_limit` → Prisma default `numCPUs*2+1`.
- Prisma sizes off the **host's physical CPUs, not the pod cgroup limit**. zeus nodes are
  `m8g.24xlarge` = 96 vCPU → **193 connections per pod**. 2 `graph` replicas = 386;
  `prod-us-west-2-main-nova-staging` ceiling is 392.
- Pools fill lazily and **never shrink**, so one traffic bump pins the DB permanently
  (flat 392, zero variance, no deploy or replica change).

`packages/authz/src/lib/prisma.ts:22-25` already guards this (`connection_limit=10`) and its
comment names the trap — the guard was just never applied to graph/capital-api.

Unblock: `kubectl -n nova-staging rollout restart deployment/graph`, then
`kubectl delete job nova-graph-dbmigrate` (a Job at its backoff limit will NOT retry — Argo
needs a fresh one), then re-sync.

Diagnosing without k8s RBAC (kevin's kubectl is Forbidden in `nova-staging` on hermes and
zeus — see [[nova-prod-db-access-from-bridge]]): the migrate pod logs land in Datadog under
`service:nova-graph`, and `avg:aws.rds.database_connections{dbinstanceidentifier:prod-us-west-2-main-nova-staging-0}`
with `raw_data:true` shows the step. A flat max with min==max is saturation, not load.

Unrelated noise found in the same namespace: staging Hasura is internet-exposed (wp-login /
Ivanti scanner traffic), and `nova-graph` pods are tagged `env:prod` in Datadog while
`capital-api` is `env:staging`.
